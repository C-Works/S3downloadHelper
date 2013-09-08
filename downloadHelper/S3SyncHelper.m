//
//  S3SyncHelper.m
//  S3SyncHelper
//
//  Created by Jonathan Dring on 24/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import "S3SyncHelper.h"
#import "S3RequestHelper.h"

// ---------------------------------------------------------------------------------------------------------------------
// Module Definitions
// ---------------------------------------------------------------------------------------------------------------------
#define S3DH_RHANDLER_DOMAIN @"co.c-works.s3dh.s3sh"

// ---------------------------------------------------------------------------------------------------------------------
// Interface Definition
// ---------------------------------------------------------------------------------------------------------------------
@interface S3SyncHelper () <S3RequestHelperDelegateProtocol>
{
    AmazonS3Client      *_s3;               
    NSString            *_bucket;
    
    int                 _retryTime;
    
    NSArray             *_S3BucketObjectList;
    NSMutableDictionary *_S3RequestHelpers;

    NSMutableDictionary *_S3ObjectSummaries;

    Reachability        *_bucketReachability;           // Reachability status for the specified bucked and location.
    SYNC_STATUS         _status;
    Boolean             _isEnabled;
}
@end

// ---------------------------------------------------------------------------------------------------------------------
// Class Implementation
// ---------------------------------------------------------------------------------------------------------------------
@implementation S3SyncHelper

// ---------------------------------------------------------------------------------------------------------------------
// Synthesized Getters & Setters
// ---------------------------------------------------------------------------------------------------------------------
@synthesize bucketReachability  = _bucketReachability;
@synthesize status              = _status;

// ---------------------------------------------------------------------------------------------------------------------
// Initialisation Methods
// ---------------------------------------------------------------------------------------------------------------------
- (id)initWithS3Client:(AmazonS3Client*)client forBucket:(NSString*)bucket
{
    self = [super init];
    if( self ){
        
        if ( ! client ) return nil;
        if ( ! bucket ) return nil;
        
        _s3            = client;
        _bucket        = bucket;
        _retryTime     = DEFAULT_RETRY_TIME;
        _status        = dhINITIALISED;
        _isEnabled     = YES;
        
        _S3RequestHelpers  = [[NSMutableDictionary alloc] init];
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

// ---------------------------------------------------------------------------------------------------------------------
// Public Control Methods
// ---------------------------------------------------------------------------------------------------------------------
-(void)resumeSynchronisation{
    if ( [ _bucketReachability isReachable] && _status != dhDOWNLOADING && _status != dhCOMPLETE ){
        NSLog(@"synchronisationResumed");
        _status = dhDOWNLOADING;
        _isEnabled = YES;
        [self performSelectorInBackground:@selector(asyncSynchroniseBucket) withObject:nil];
    }
}

- (void)suspendSynchronisation{
    if( _status != dhSUSPENDED ){
        _status = dhSUSPENDED;
        _isEnabled = NO;
        NSLog(@"synchronisationSuspended");
        
        for( NSString *key in _S3RequestHelpers )
        {
            S3RequestHelper *s3rh      = [ _S3RequestHelpers objectForKey: key ];
            switch (s3rh.state) {
                case INITIALISED:
                    NSLog(@"[INITIALISED]:%@", key);
                    break;
                case DOWNLOADING:
                    NSLog(@"Suspend:%@", key);
                    [s3rh suspend];
                    break;
                case SUSPENDED:
                    NSLog(@"[SUSPENDED]:%@", key);
                    break;
                case TRANSFERED:
                    NSLog(@"[COMPLETE]:%@", key);
                    break;
                case SAVED:
                    NSLog(@"[CANCELLED]:%@", key);
                    break;
                case FAILED:
                    NSLog(@"[FAILED]:%@", key);
                    break;
            }
        }
    }
}


-(void)asyncSynchroniseBucket{
    _S3BucketObjectList = [_s3 listObjectsInBucket: _bucket ];
    [self performSelectorOnMainThread:@selector(syncSynchroniseBucket) withObject:nil waitUntilDone:NO];
}

-(void)syncSynchroniseBucket{
    NSError *error;
    
    // Clear Object Summaries and process S3ObjectList for non folder items.
    _S3ObjectSummaries  = [[NSMutableDictionary alloc] init];
    
    for( S3ObjectSummary *S3summary in _S3BucketObjectList ){
        if( ! [S3summary.key hasSuffix: @"/" ] ){
            [ _S3ObjectSummaries setObject: S3summary forKey: S3summary.key ];
        }
    }
    
    // Generate new S3RequestHelpers dictionary from existing and new handlers.
    NSMutableDictionary *refreshedS3RequestHelpers = [[NSMutableDictionary alloc] init];
    for( NSString *key in _S3ObjectSummaries ){
        
        S3ObjectSummary *S3summary  = [ _S3ObjectSummaries objectForKey: key ];
        S3RequestHelper *s3rh      = [ _S3RequestHelpers objectForKey: key ];
        
        if( !s3rh ){
            s3rh = [[S3RequestHelper alloc] initWithS3ObjectSummary:S3summary S3Client:_s3 bucket:_bucket delegate:self error:error];
        }
        [s3rh download];

        [ refreshedS3RequestHelpers setObject: s3rh forKey: key ];
        [_S3RequestHelpers removeObjectForKey: S3summary.key ];
    }
    
    // Purge out-of-date handlers, reset them before deleting and then copy new handler list to old handler list.
    for( NSString *key in _S3ObjectSummaries ){
        [[ _S3RequestHelpers objectForKey: key ] reset ];
        [ _S3RequestHelpers removeObjectForKey: key ];
    }
    _S3RequestHelpers = refreshedS3RequestHelpers;
}

// ---------------------------------------------------------------------------------------------------------------------
// PROTOCOL Methods - S3RequestHelperDelegateProtocol
// ---------------------------------------------------------------------------------------------------------------------
-(BOOL)downloadEnable{
    return _bucketReachability.isReachable && _isEnabled;
}

-(NSString*)downloadPath:(S3RequestHelper*)s3rh{
    
    NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0 ];
    NSString *temp = [[NSString alloc] initWithFormat:@"%@.tmp", s3rh.key ];
    return [root stringByAppendingPathComponent: temp ];
}

-(NSString*)persistPath:(S3RequestHelper*)s3rh{
    
    NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0 ];
    return [root stringByAppendingPathComponent: s3rh.key ];
}

-(BOOL)validateMD5forDownload:(S3RequestHelper*)s3rh{

    return [ s3rh.md5 isEqualToString: [ S3SyncHelper md5: s3rh.downloadPath ] ];
}

-(BOOL)validateMD5forPersist:(S3RequestHelper*)s3rh{
    
    return [ s3rh.md5 isEqualToString: [ S3SyncHelper md5: s3rh.persistPath ] ];
}

-(void)downloadFinished:(S3RequestHelper *)s3rh{
    
    // Need persistence strategy.
    [s3rh persist];
    
    BOOL downloadComplete   = true;
    BOOL downloadFailed     = true;
    
    for ( NSString *key in _S3RequestHelpers ){
        S3RequestHelper *s3rhTemp = [ _S3RequestHelpers objectForKey: key ];
        if ( s3rhTemp.state != TRANSFERED ) downloadComplete = false;
        if ( s3rhTemp.state != FAILED   ) downloadFailed   = false;
    }
    
    if ( downloadComplete ){
        // Call each _s3RequestHelper and save data then destroy handlers
    }
    
    if ( downloadFailed ){
        NSTimeInterval delay = 60 * 60 * _retryTime;
        [self performSelector: @selector(synchroniseBucket) withObject: nil afterDelay: delay ];
    }
}

- (void)downloadFailed:( S3RequestHelper * )s3rh{
    
    NSLog(@"Download Failed Error: %@", s3rh.error.localizedDescription );
    
    [s3rh reset];
    [s3rh download];
}

- (void)progressChanged:(S3RequestHelper*)s3rh{
    // Demo method, prints progress of a file to the log window. Progress changed is only called
    NSLog(@"Download:%d%% [%@]", s3rh.progress, [[s3rh.key componentsSeparatedByString:@"/"] lastObject] );
}

- (BOOL)persistFile:(S3RequestHelper*)s3rh{

    NSFileManager *fManager = [[NSFileManager alloc]init];
    
    return [ fManager moveItemAtPath:s3rh.downloadPath toPath:s3rh.persistPath error: nil ];    
}

// ---------------------------------------------------------------------------------------------------------------------
// Support Methods
// ---------------------------------------------------------------------------------------------------------------------

// Calculates an md5 for a specified path, reads incrementally to handle large files.
+(NSString*)md5:(NSString*)path{
    
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
// ---------------------------------------------------------------------------------------------------------------------


@end
