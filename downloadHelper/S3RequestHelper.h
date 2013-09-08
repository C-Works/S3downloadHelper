//
//  S3RequestHandler.h
//  downloadHelper
//
//  Created by Jonathan Dring on 24/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import "S3SyncHelper.h"
#import "S3RequestHelperDelegateProtocol.h"

@class AmazonS3Client;
@class S3ObjectSummary;

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
    S3DH_RHANDLER_FOLDER_FAIL,
    S3DH_RHANDLER_FILE_STREAM_FAIL,
    S3DH_RHANDLER_FILE_PERSIST_FAIL,
    S3DH_RHANDLER_FILE_DL_OVERRUN,
    S3DH_RHANDLER_DOWNLOAD_ERROR,
    S3DH_RHANDLER_RETRY_EXCEEDED
};

typedef enum{
    INITIALISED,
    DOWNLOADING,
    SUSPENDED,
    FAILED,
    TRANSFERED,
    SAVED
} REQUEST_STATE;


@interface S3RequestHelper:NSObject


-(id)initWithS3ObjectSummary:(S3ObjectSummary*)s S3Client:(AmazonS3Client*)c bucket:(NSString*)b  delegate:(id)d error:(NSError*)e;

- (BOOL)suspend;
- (BOOL)reset;
- (BOOL)download;
- (BOOL)persist;


@property (nonatomic, readonly) int                   progress;
@property (nonatomic, readonly) REQUEST_STATE         state;
@property (nonatomic, readonly) NSString              *key;
@property (nonatomic, readonly) NSString              *md5;

@property (nonatomic, readonly) NSString              *downloadPath;
@property (nonatomic, readonly) NSString              *persistPath;

@property (nonatomic, readonly) NSError               *error;
@property (nonatomic, readonly) NSException           *exception;



@end
