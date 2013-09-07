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


enum S3DHErrorCodes {
    S3DH_RHANDLER_SUCCESS = 0,         // Default Code if there is no error.
    S3DH_RHANDLER_NIL_CLIENT,
    S3DH_RHANDLER_NIL_BUCKET,
    S3DH_RHANDLER_NIL_DELEGATE,
    S3DH_RHANDLER_NIL_SUMMARY,
    S3DH_RHANDLER_FILE_UNWRITABLE,     // Reset method can't confirm writtability to specified location.
    S3DH_RHANDLER_FILE_CREATE_FAIL,
    S3DH_RHANDLER_FILE_INIT_FAIL,
    S3DH_RHANDLER_FOLDER_FAIL
};

typedef enum{
    INITIALISED,
    DOWNLOADING,
    SUSPENDED,
    FAILED,
    TRANSFERED,
    SAVED
} REQUEST_STATE;


@interface S3RequestHandler:NSObject
{
}

@property (nonatomic, readonly) float                   progress;
@property (nonatomic, readonly) NSString                *key;

@property (nonatomic, readonly) AmazonServiceResponse *response;
@property (nonatomic, readonly) NSError               *error;
@property (nonatomic, readonly) NSException           *exception;
@property (nonatomic, readonly) S3ObjectSummary       *S3ObjectSummary;

@property (nonatomic, readonly) int                   attempts;
@property (nonatomic, readonly) REQUEST_STATE         state;
@property (nonatomic, readonly) NSString              *md5;

@property (nonatomic, weak) id <S3RequestHandlerDelegateProtocol> delegate;

-(id)initWithS3ObjectSummary:(S3ObjectSummary*)s S3Client:(AmazonS3Client*)c bucket:(NSString*)b  delegate:(id)d error:(NSError*)e;

//- (REQUEST_STATE)status;
- (BOOL)suspend;
- (BOOL)reset;
- (BOOL)download;
- (BOOL)persist;


- (void)interruptedDownload;
- (void) rhError:(int)code data:(NSString*)data error:(NSError**)errorp;

@end
