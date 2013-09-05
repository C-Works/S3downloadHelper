/*
 * Copyright 2010-2013 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

#import "S3RequestHandlerDelegateProtocol.h"
#import "Reachability.h"
#import "downloadHelper.h"

@class AmazonServiceResponse;
@class S3ObjectSummary;
@class AmazonS3Client;

#define DEFAULT_RETRY_LIMIT 3           // Number of consecutive attempts at downloading.
#define DOWNLOAD_BLOCK_SIZE 1048576     // Number of bytes to try and download at one time.

typedef enum{
    INITIALISED,
    DOWNLOADING,
    BLOCKCOMPLETE,
    SUSPENDED,
    FAILED,
    TRANSFERED,
    SAVED
} REQUEST_STATE;


@interface S3RequestHandler:NSObject
{
}

@property (nonatomic, readonly) AmazonServiceResponse *response;
@property (nonatomic, readonly) NSError               *error;
@property (nonatomic, readonly) NSException           *exception;
@property (nonatomic, readonly) S3ObjectSummary       *S3ObjectSummary;

@property (nonatomic, readonly) int                   attempts;
@property (nonatomic, readonly) REQUEST_STATE         state;
@property (nonatomic, readonly) NSString              *eTag;

@property (nonatomic, weak) id <S3RequestHandlerDelegateProtocol> delegate;

-(id)initWithS3Obj:(S3ObjectSummary*)obj inBucket:(NSString*)bucket destPath:(NSString*)path withS3client:(AmazonS3Client*)client error:(NSError*)error;

//- (REQUEST_STATE)status;
-(BOOL)suspend;
-(BOOL)reset;
-(BOOL)download;
-(BOOL)save;

@end
