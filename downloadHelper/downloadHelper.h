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

#import "S3RequestHandlerDelegateProtocol.h"

#import <CommonCrypto/CommonDigest.h>
#import "Constants.h"

#define CHUNK_SIZE          100000
#define DEFAULT_RETRY_TIME  29      // Number of hours to wait after default retry limit.


@interface downloadHelper : NSObject <S3RequestHandlerDelegateProtocol>

- (id)initWithS3Client:(AmazonS3Client*)client forBucket:(NSString*)bucket;

- (void) resumeSynchronisation;
- (void) suspendSynchronisation;


// S3RequestHandlerDelegateProtocol

- (void)downloadFinished:(S3RequestHandler *)request;
- (NSString*)downloadFilePath:(S3RequestHandler*)S3RequestHandler;
- (NSString*)persistedFilePath:(S3RequestHandler*)S3RequestHandler;


+ (BOOL)validateMD5forSummary:(S3ObjectSummary*)object withPath:(NSString*)path;

+ (BOOL)validateMD5forFile:(NSString*)md5 withPath:(NSString*)path;

+(NSString*)fileMD5:(NSString*)path;

@property (strong, atomic) Reachability             *bucketReachability;
@property (atomic, readonly) SYNC_STATUS            status;


@end
