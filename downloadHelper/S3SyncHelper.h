//
//  downloadHelper.h
//  downloadHelper
//
//  Created by Jonathan Dring on 24/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AWSRuntime/AWSRuntime.h>
#import <AWSS3/AmazonS3Client.h>
#import <AWSS3/AWSS3.h>
#import "Reachability.h"

#import "S3RequestHelperDelegateProtocol.h"

#import <CommonCrypto/CommonDigest.h>
#import "Constants.h"

#define CHUNK_SIZE          100000
#define DEFAULT_RETRY_TIME  29      // Number of hours to wait after default retry limit.


@interface S3SyncHelper : NSObject <S3RequestHelperDelegateProtocol>

- (id)initWithS3Client:(AmazonS3Client*)c forBucket:(NSString*)b delegate:(id)d;

- (void) resumeSynchronisation;
- (void) suspendSynchronisation;



-(void)includeAll;
-(void)synchronise;

@property (strong, atomic) Reachability             *bucketReachability;
@property (atomic, readonly) SYNC_STATUS            status;



// S3RequestHandlerDelegateProtocol

- (void)progressChanged:(S3RequestHelper*)s3rh;

- (NSString*)downloadPath:(S3RequestHelper*)s3rh;
- (NSString*)persistPath:(S3RequestHelper*)s3rh;


- (BOOL)validateMD5forDownload:(S3RequestHelper*)s3rh;
- (BOOL)validateMD5forPersist:(S3RequestHelper*)s3rh;

- (void)downloadFinished:( S3RequestHelper * )s3rh;
- (void)downloadFailed:( S3RequestHelper * )s3rh;

+(NSString*)md5:(NSString*)path;

@end
