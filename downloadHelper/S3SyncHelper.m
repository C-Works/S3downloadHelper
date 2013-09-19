//
//  S3SyncHelper.m
//  S3SyncHelper
//
//  Created by Jonathan Dring on 24/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import "S3SyncHelper.h"
#import "S3RequestHelper.h"
#import "S3downloadHelperDelegateProtocol.h"

// ---------------------------------------------------------------------------------------------------------------------
// Module Definitions
// ---------------------------------------------------------------------------------------------------------------------
#define S3DH_RHANDLER_DOMAIN @"co.c-works.s3dh.s3sh"

// ---------------------------------------------------------------------------------------------------------------------
// Interface Definition
// ---------------------------------------------------------------------------------------------------------------------
@interface S3SyncHelper () <S3RequestHelperDelegateProtocol>
{
    AmazonS3Client      *_s3;                       // Amazon client used to connect, provided during initialisation.
    NSString            *_bucket;                   // Amazon bucket name to download, provided during initialisation.
    id <S3downloadHelperDelegateProtocol> _delegate;// Delegate object to report back to.

    int                 _retryTime;
    
    NSArray             *_S3BucketObjectList;
    NSMutableDictionary *_S3RequestHelpers;
    
    NSMutableDictionary *_S3ActiveHelpers;
    NSMutableDictionary *_S3SleepingHelpers;
    
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
- (id)initWithS3Client:(AmazonS3Client*)c forBucket:(NSString*)b delegate:(id)d
{
    self = [super init];
    if( self ){
        
        if ( ! ( _s3       = c ) ) return nil;
        if ( ! ( _bucket   = b ) ) return nil;
        if ( ! ( _delegate = d ) ) return nil;
        
        _retryTime     = DEFAULT_RETRY_TIME;
        _status        = dhINITIALISED;
        _isEnabled     = YES;

        _S3ActiveHelpers    = [[NSMutableDictionary alloc] init];
        _S3SleepingHelpers  = [[NSMutableDictionary alloc] init];

        _S3RequestHelpers   = [[NSMutableDictionary alloc] init];
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
            [weakSelf performSelectorInBackground:@selector(updateRequestHelpers) withObject:nil];
            
//            [weakSelf isReachable ];
        };
        
        _bucketReachability.unreachableBlock = ^(Reachability*reach){
            NSLog(@"S3 Bucket UNREACHABLE!");
            [weakSelf isUnreachable];
        };
        [_bucketReachability startNotifier];
    }
    return self;
}

// ---------------------------------------------------------------------------------------------------------------------
// Public Control Methods
// ---------------------------------------------------------------------------------------------------------------------
- (void)isUnreachable{
    
    if( _status != dhSUSPENDED ){
        _status = dhSUSPENDED;
        _isEnabled = NO;

        NSLog(@"Suspend all downloads");
        for( NSString *key in _S3RequestHelpers ){
            S3RequestHelper *s3rh = [_S3RequestHelpers objectForKey:key  ];
            [s3rh suspend];
        }
    }
}

// Fetches the latest bucket list and updates the S3RequestHanlers dictionary.
-(void)updateRequestHelpers{
    NSError *error;
    
    [_s3 setConnectionTimeout: (NSTimeInterval) 60.0 ];

    @try{
        _S3BucketObjectList = [_s3 listObjectsInBucket: _bucket ];
    }
    @catch ( AmazonServiceException *serviceException ) {
        NSLog(@"Service Exception Occured: %@", serviceException.errorCode);
        [_delegate bucketListUpdateFailed:self];
    }
    @catch (AmazonClientException *clientException) {
        NSLog(@"Client Exception Occured: %@", clientException.error.localizedDescription);
        [_delegate bucketListUpdateFailed:self];
    }
    @finally {
        
        BOOL bucketlistDidChange = false;
        
        // Clear Object Summaries and process S3ObjectList for non folder items.
        NSMutableDictionary *S3RefreshedHelpers = [[NSMutableDictionary alloc] init];
        for( S3ObjectSummary *S3summary in _S3BucketObjectList ){
            if( ! [S3summary.key hasSuffix: @"/" ] ){

                S3RequestHelper *s3rh      = [ _S3RequestHelpers objectForKey: S3summary.key ];
                if( !s3rh ){
                    s3rh = [[S3RequestHelper alloc] initWithS3ObjectSummary:S3summary S3Client:_s3 bucket:_bucket delegate:self error:error];
                    bucketlistDidChange = true;
                }
                [ S3RefreshedHelpers setObject: s3rh forKey: S3summary.key ];
                [_S3RequestHelpers removeObjectForKey: S3summary.key ];
            }
        }
        
        // Cancel Orphans and update the request helpers list.
        for (S3RequestHelper *s3rh in _S3RequestHelpers ) {
            bucketlistDidChange = true;
            [s3rh cancel];
        }
        _S3RequestHelpers = S3RefreshedHelpers;

        
        switch (_status) {
            case dhINITIALISED:
                _status = dhUPDATED;
                break;
            case dhUPDATED:         break;
            case dhSYNCHRONISED:    break;
            case dhSYNCHRONISING:   break;
            case dhSUSPENDED:       break;
        }

        if(bucketlistDidChange){
            [_delegate bucketlistDidUpdate];
        }
        
        // Call the delegate and inform it that the bucklist update is ready.
        
    }
}

-(void)synchronise{
    
    if( _status == dhUPDATED || _status == dhSYNCHRONISED ){

        _isEnabled = true;
        _status = dhSYNCHRONISING;
        for( NSString *key in _S3RequestHelpers ){
            S3RequestHelper *s3rh      = [ _S3RequestHelpers objectForKey: key ];
            [s3rh synchronise];
        }
        
    }

}

-(void)includeAll{
    for( NSString *key in _S3RequestHelpers ){

        [ self includeKey: key ];
    }
}

-(BOOL)includeKey:(NSString*)key{
    
    S3RequestHelper *s3rh = [ _S3RequestHelpers objectForKey: key ];

    if ( ! [_S3ActiveHelpers objectForKey: key] ) {
        [_S3ActiveHelpers setObject:s3rh forKey:key];
    }
    
    if ( [_S3SleepingHelpers objectForKey: key] ){
        [_S3SleepingHelpers removeObjectForKey: key];
    }
    
}


// ---------------------------------------------------------------------------------------------------------------------
// PROTOCOL Methods - S3RequestHelperDelegateProtocol
// ---------------------------------------------------------------------------------------------------------------------
-(BOOL)downloadEnable{
    BOOL enabled =_bucketReachability.isReachable && _isEnabled;
    return enabled;
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
    [s3rh synchronise];
}

- (void)progressChanged:(S3RequestHelper*)s3rh{
    // Demo method, prints progress of a file to the log window. Progress changed is only called
    NSLog(@"Download:%d%% [%@]", s3rh.progress, [[s3rh.key componentsSeparatedByString:@"/"] lastObject] );
}

- (BOOL)persistFile:(S3RequestHelper*)s3rh{

    NSFileManager *fManager = [[NSFileManager alloc]init];
    
    return [ fManager moveItemAtPath:s3rh.downloadPath toPath:s3rh.persistPath error: nil ];    
}

- (BOOL)deleteFile:(S3RequestHelper *)s3rh{

    NSFileManager *fManager = [[NSFileManager alloc]init];
    
    return [ fManager removeItemAtPath:s3rh.downloadPath error: nil ];
    
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
