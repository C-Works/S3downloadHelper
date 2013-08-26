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

#import "S3RequestHandlerDelegateProtocol.h"

#import <CommonCrypto/CommonDigest.h>
#import "Constants.h"


#define CHUNK_SIZE 100000


@interface downloadHelper : NSObject <S3RequestHandlerDelegateProtocol>

- (id)initWithS3Client:(AmazonS3Client*)client forBucket:(NSString*)bucket;

- (void) synchroniseBucket;


// S3RequestHandlerDelegateProtocol

- (void)downloadComplete:(S3RequestHandler *)request;
- (void)downloadFailedWithError:(NSError *)error;
- (void)downloadFailedWithException:(NSException*)exception;


@end
