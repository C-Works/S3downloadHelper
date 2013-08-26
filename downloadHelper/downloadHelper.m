//
//  downloadHelper.m
//  downloadHelper
//
//  Created by Jonathan Dring on 24/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import "downloadHelper.h"
#import "S3RequestHandler.h"



@interface downloadHelper () <S3RequestHandlerDelegateProtocol>
{
    AmazonS3Client      *_s3;
    NSString            *_bucket;
    
    NSArray             *_S3ObjectList;
    NSMutableDictionary *_S3FileObjects;
    NSMutableDictionary *_S3FileStatus;
    NSMutableArray      *_requestHandlers;
}
@end

@implementation downloadHelper

- (id)initWithS3Client:(AmazonS3Client*)client forBucket:(NSString*)bucket
{
    self = [super init];
    if( self ){
        
        if ( ! client ) return nil;
        if ( ! bucket ) return nil;
        
        _s3     = client;
        _bucket = bucket;

        _S3FileObjects   = [[NSMutableDictionary alloc] init];
        _requestHandlers = [[NSMutableArray alloc] init];
        
    }
    return self;
}

-(void)downloadComplete:(S3RequestHandler *)request{
    
}
-(void)downloadFailedWithError:(NSError *)error{
    
}
- (void)downloadFailedWithException:(NSException*)exception{
    
}

-(void)synchroniseBucket{
   [self performSelectorInBackground:@selector(asyncSynchroniseBucket) withObject:nil];
}

-(void)asyncSynchroniseBucket{
    _S3ObjectList = [_s3 listObjectsInBucket: _bucket ];
    [self performSelectorOnMainThread:@selector(syncSynchroniseBucket) withObject:nil waitUntilDone:NO];
}

-(void)syncSynchroniseBucket{
    NSError *error;
    
    NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0 ];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    

    for( S3ObjectSummary *o in _S3ObjectList){
        
        NSString *filePath = [root stringByAppendingPathComponent: o.key ];
        BOOL isDir;
        BOOL pathExists = [fileManager fileExistsAtPath: filePath isDirectory: &isDir ];

        // Object is a folder...
        if ( [o.key hasSuffix: @"/" ]  ){

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
        
        }// Object is a file
        else  if( !( [[ self objectS3eTag: o ] isEqualToString:[ downloadHelper fileMD5: filePath ] ] ) ){
            [_S3FileStatus  setObject: @"Pending" forKey: o.key ];
            [_S3FileObjects setObject: o forKey: o.key];
        }
    }
        
    for( NSString *key in _S3FileObjects ){
        
        S3ObjectSummary *o = [_S3FileObjects objectForKey: key ];
        
        NSString *filePath = [root stringByAppendingPathComponent: o.key ];
        BOOL isDir;
        BOOL pathExists = [fileManager fileExistsAtPath: filePath isDirectory: &isDir ];

        if( pathExists && isDir ){
                // This file is a folder, need to delete.
            NSLog(@"isDirectory");
        }
        else if( !pathExists ){
                //Create file on the S3 folder..
//                [AmazonLogger verboseLogging];

            S3RequestHandler *r = [[S3RequestHandler alloc] initWithS3Obj:o inBucket:_bucket destPath:filePath withS3client:_s3 error:error ];
            [_requestHandlers addObject:r];
        }
        else if( !( [[ self objectS3eTag: o ] isEqualToString:[ downloadHelper fileMD5: filePath ] ] ) ){
                // File exists but the MD5 has changed on the bucket, need to update...

//                [self downloadKey:o.key];
//                _filePathToSaveTo = filePath;
        }

    }
    
}
// ---------------------------------------------------------------------------------------------------------------------
- (NSString*)objectS3eTag:(S3ObjectSummary*)object{
    
    NSString *s;
    NSString *eTag;
    
    eTag = object.etag;
        
    s = [eTag stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@"\""]];
    
    return s;
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
