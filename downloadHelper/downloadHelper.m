//
//  downloadHelper.m
//  downloadHelper
//
//  Created by Jonathan Dring on 24/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import "downloadHelper.h"
#import "S3RequestHandler.h"

@class Reachability;
@class S3RequestHandler;

@interface downloadHelper () <S3RequestHandlerDelegateProtocol>
{
    AmazonS3Client      *_s3;
    
    NSString            *_bucket;
    
    int                 _retryTime;
    
    NSArray             *_S3BucketObjectList;
    NSMutableDictionary *_S3RequestHandlers;

    NSMutableDictionary *_S3ObjectSummaries;

    Reachability        *_bucketReachability;
    SYNC_STATUS         _status;
}
@end

@implementation downloadHelper

@synthesize bucketReachability = _bucketReachability;

- (id)initWithS3Client:(AmazonS3Client*)client forBucket:(NSString*)bucket
{
    self = [super init];
    if( self ){
        
        if ( ! client ) return nil;
        if ( ! bucket ) return nil;
        
        _s3                 = client;
        _bucket             = bucket;
        _retryTime          = DEFAULT_RETRY_TIME;
        _status             = dhINITIALISED;
        
        _S3RequestHandlers  = [[NSMutableDictionary alloc] init];
        _S3ObjectSummaries  = [[NSMutableDictionary alloc] init];
        
        // Get the bucket host for reachability observer from a urlRequest object
        S3GetPreSignedURLRequest *urlRequest = [[S3GetPreSignedURLRequest alloc] init];
        urlRequest.bucket = _bucket;
        urlRequest.endpoint = _s3.endpoint;
        NSString *bucketURL = urlRequest.host;
        
        _bucketReachability = [Reachability reachabilityWithHostname: bucketURL ];
        _bucketReachability.reachableOnWWAN = YES;
        
        __weak typeof(self) weakSelf = self;
        _bucketReachability.reachableBlock = ^(Reachability*reach){
            NSLog(@"S3 Bucket REACHABLE!");
            [weakSelf resumeSynchronisation];
        };
        
        _bucketReachability.unreachableBlock = ^(Reachability*reach){
            NSLog(@"S3 Bucket UNREACHABLE!");
            [weakSelf suspendSynchronisation];
        };

        [_bucketReachability startNotifier];
    }
    return self;
}

-(void)resumeSynchronisation{
    if ( [ _bucketReachability isReachable] && _status != dhDOWNLOADING && _status != dhCOMPLETE ){
        NSLog(@"synchronisationResumed");
        _status = dhDOWNLOADING;
        [self performSelectorInBackground:@selector(asyncSynchroniseBucket) withObject:nil];
    }
}

- (void)suspendSynchronisation{
    if( _status != dhSUSPENDED ){
        _status = dhSUSPENDED;
        NSLog(@"synchronisationSuspended");
        
        for( NSString *key in _S3RequestHandlers )
        {
            S3RequestHandler *s3rh      = [ _S3RequestHandlers objectForKey: key ];
            switch (s3rh.state) {
                case INITIALISED:
                    NSLog(@"[INITIALISED]:%@", key);
                    break;
                case DOWNLOADING:
                    NSLog(@"Suspend:%@", key);
                    [s3rh suspendDownload];
                    break;
                case CANCELLED:
                    NSLog(@"[CANCELLED]:%@", key);
                    break;
                case COMPLETE:
                    NSLog(@"[COMPLETE]:%@", key);
                    break;
                case FAILED:
                    NSLog(@"[FAILED]:%@", key);
                    break;
                case SUSPENDED:
                    NSLog(@"[SUSPENDED]:%@", key);
                    break;
            }
        }
    }
}



-(BOOL)isReachable{
    return _bucketReachability.isReachable;
}

-(void)downloadFinished:(S3RequestHandler *)request{
    
    BOOL downloadComplete   = true;
    BOOL downloadFailed     = true;
    
    for ( NSString *key in _S3RequestHandlers ){
        S3RequestHandler *s3rh = [ _S3RequestHandlers objectForKey: key ];
        if ( s3rh.state != COMPLETE ) downloadComplete = false;
        if ( s3rh.state != FAILED   ) downloadFailed   = false;
    }
        
    if ( downloadComplete ){
        // Call each _s3RequestHAndler and save data then destroy handlers
    }

    if ( downloadFailed ){
        NSTimeInterval delay = 60 * 60 * _retryTime;
        [self performSelector: @selector(synchroniseBucket) withObject: nil afterDelay: delay ];
    }
}



- (void)downloadFailed:( S3RequestHandler * )request{
    NSLog(@"Failed Download Retry: %@", request.S3ObjectSummary.key);
    
    [request tryDownload];
}


-(void)asyncSynchroniseBucket{
    _S3BucketObjectList = [_s3 listObjectsInBucket: _bucket ];
    [self performSelectorOnMainThread:@selector(syncSynchroniseBucket) withObject:nil waitUntilDone:NO];
}

-(void)syncSynchroniseBucket{
    NSError *error;
    NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0 ];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    
    // Clean out the object summaries, ready to create a new list of current download needs.
    _S3ObjectSummaries  = [[NSMutableDictionary alloc] init];

    for( S3ObjectSummary *S3summary in _S3BucketObjectList ){
        
        NSString *filePath = [root stringByAppendingPathComponent: S3summary.key ];
        BOOL isDir;
        BOOL pathExists = [fileManager fileExistsAtPath: filePath isDirectory: &isDir ];

        // Object is a folder...
        if ( [S3summary.key hasSuffix: @"/" ]  ){

            if( pathExists && !isDir ){
                // This folder exists as a file, it should be deleted...
                
            }
            else if( !pathExists ){
                // The folder doesn't exist so should be created...
                [fileManager createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:&error ];
            }
            else{
                // The folder exists already...
            }
        }
        // Object is a file, make a list of all objects that need downloading (new or changed)
        else  if( ! [downloadHelper validateMD5forSummary:S3summary withPath:filePath] ){
            [_S3ObjectSummaries setObject: S3summary forKey: S3summary.key];
        }
    }
    
    NSMutableDictionary *refreshedS3RequestHandlers = [[NSMutableDictionary alloc] init];
    for( NSString *key in _S3ObjectSummaries ){
        
        S3ObjectSummary *S3summary  = [ _S3ObjectSummaries objectForKey: key ];
        S3RequestHandler *s3rh      = [ _S3RequestHandlers objectForKey: key ];
        
        NSString *filePath = [root stringByAppendingPathComponent: key ];

        BOOL isDir;
        BOOL pathExists = [fileManager fileExistsAtPath: filePath isDirectory: &isDir ];

        if( pathExists && isDir ){
            // This file is a folder, need to delete.
            NSLog(@"isDirectory");
        }
        else if( !pathExists ){
            //Create file on the S3 folder..
            if ( ! s3rh ){
                // Add a request handler if non exists for this key
                s3rh = [[S3RequestHandler alloc] initWithS3Obj:S3summary inBucket:_bucket destPath:filePath withS3client:_s3 error:error ];
                s3rh.delegate = self;
                [s3rh tryDownload ];
            }
            [ refreshedS3RequestHandlers setObject: s3rh forKey: key ];
            [_S3RequestHandlers removeObjectForKey: S3summary.key ];
        }
        else if( ! [downloadHelper validateMD5forSummary:S3summary withPath: filePath] ){
            if ( s3rh.state == SUSPENDED ){
                [s3rh tryDownload];
                NSLog(@"Request Handler Exists");
            }
            else if(s3rh.state == DOWNLOADING ){
                NSLog(@"Auto-restarted.");
            }
            else{
                // File exists but the MD5 has changed on the bucket, need to update...
                [fileManager removeItemAtPath: filePath error: &error];
                
                s3rh = [[S3RequestHandler alloc] initWithS3Obj:S3summary inBucket:_bucket destPath:filePath withS3client:_s3 error:error ];
                s3rh.delegate = self;
                [s3rh tryDownload ];
            }
            
            [ refreshedS3RequestHandlers setObject: s3rh forKey: key ];
            [_S3RequestHandlers removeObjectForKey: S3summary.key ];
        }
    }
    
    // Purge old request handlers and cancel them before deleting. Update _S3RequestHandlers with RefreshedHandlers
    for( NSString *key in _S3ObjectSummaries ){
        [[ _S3RequestHandlers objectForKey: key ] cancelDownload ];
        [ _S3RequestHandlers removeObjectForKey: key ];
    }
    _S3RequestHandlers = refreshedS3RequestHandlers;
}


// ---------------------------------------------------------------------------------------------------------------------

+(BOOL)validateMD5forSummary:(S3ObjectSummary*)object withPath:(NSString*)path{
    NSString *eTagMD5;
    NSString *fileMD5;
    NSString *eTag;
    
    eTag = object.etag;
    
    eTagMD5 = [eTag stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@"\""]];
    fileMD5 = [self fileMD5: path];
    
    return [eTagMD5 isEqualToString: fileMD5];
    
}

+(NSString*)fileMD5:(NSString*)path
{
	NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
	
	CC_MD5_CTX md5;
	CC_MD5_Init(&md5);
	
    if(handle != nil){
        BOOL done = NO;
        while(!done)
        {
            @autoreleasepool {
                NSData* fileData = [handle readDataOfLength: CHUNK_SIZE ];
                CC_MD5_Update(&md5, [fileData bytes], [fileData length]);
                if( [fileData length] == 0 ) done = YES;
            }
        }
    }
	unsigned char digest[CC_MD5_DIGEST_LENGTH];
	CC_MD5_Final(digest, &md5);
	NSString* s = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
				   digest[0], digest[1],
				   digest[2], digest[3],
				   digest[4], digest[5],
				   digest[6], digest[7],
				   digest[8], digest[9],
				   digest[10], digest[11],
				   digest[12], digest[13],
				   digest[14], digest[15]];
	return s;
}


@end
