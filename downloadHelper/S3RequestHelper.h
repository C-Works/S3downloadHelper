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
#define TIME_OUT_INTERVAL 30            // Number of seconds a download will try before cancelling a block and restarting.

enum S3DHErrorCodes {
    S3DH_RHELPER_SUCCESS = 0,         // Default Code if there is no error.
    S3DH_RHELPER_NIL_CLIENT,
    S3DH_RHELPER_NIL_BUCKET,
    S3DH_RHELPER_NIL_DELEGATE,
    S3DH_RHELPER_NIL_SUMMARY,
    S3DH_RHELPER_FILE_UNWRITABLE,     // Reset method can't confirm writtability to specified location.
    S3DH_RHELPER_FILE_CREATE_FAIL,
    S3DH_RHELPER_FILE_INIT_FAIL,
    S3DH_RHELPER_FOLDER_FAIL,
    S3DH_RHELPER_FILE_STREAM_FAIL,
    S3DH_RHELPER_FILE_PERSIST_FAIL,
    S3DH_RHELPER_FILE_DL_OVERRUN,
    S3DH_RHELPER_DOWNLOAD_ERROR,
    S3DH_RHELPER_RETRY_EXCEEDED
};

typedef enum{
    INITIALISED,
    DOWNLOADING,
    SUSPENDED,
    FAILED,
    TRANSFERED,
    SAVED,
    CANCELLED
} REQUEST_STATE;


@interface S3RequestHelper:NSObject

///-------------------------------------------------------------------------------------------------
/// @name Initialisation Methods
///-------------------------------------------------------------------------------------------------

-(id)initWithS3ObjectSummary:(S3ObjectSummary*)s S3Client:(AmazonS3Client*)c bucket:(NSString*)b  delegate:(id)d error:(NSError*)e;

///---------------------------------------------------------------------------------------
/// @name Download Control Methods
///---------------------------------------------------------------------------------------

/** Used by the controlling delegate to Suspend a download, not more data will be saved, download is fired if the block completes.
    If the delegates downloadEnable is true when download is fired, the download will auto-restart, if it is false the download will
    remain SUSPENDED.
 */
- (BOOL)suspend;

/** Resets a download from any state to initialised, all files will be deleted and all variables reset to initial conditions. Use
    this method if the download is in the FAILED state prior to calling the download method, or to stop a currently active download.
 */
- (BOOL)reset;

/** Starts the download if it is not currently active, if the download has been SUSPENDED and the block has not completed, this method
    will not restart the download.
 */
- (BOOL)synchronise;

/** Method will only work when the download has reached the TRANSFERED state, indicating that the download completed successfully and 
    the file downloaded to the temporary location has a valid checksum and no errors or exceptions reported.
 */
- (BOOL)persist;


- (BOOL)cancel;

///---------------------------------------------------------------------------------------
/// @name Properties
///---------------------------------------------------------------------------------------

/** Reports download progress in percent complete.
 */
@property (nonatomic, readonly) int                   progress;

/** Reports the state of the download item, options are:
    INITIALISED  - RequestHelper successfully initialised but download not started.
    DOWNLOADING  - RequestHelper downloading file, download not yet complete see progress property.
    SUSPENDED    - RequestHelper downloading suspended download, will auto-restart if permitted by downloadEnabled property on delegate.
    FAILED       - RequestHelper download has failed, see error or excpetion properties for explanation. Reset and download to restart.
    TRANSFERED   - RequestHelper download completed successfully, pending persistence to move from temporary location to permanent.
    SAVED        - REquestHelper download complete and file persisted to final location.
 */
@property (nonatomic, readonly) REQUEST_STATE         state;

/** AWS path definition for the file being downloaded by this object.
 */
@property (nonatomic, readonly) NSString              *key;

/** MD% checksum of the file located at the specified key location on the AWS bucket.
 */
@property (nonatomic, readonly) NSString              *md5;

/** Temporary file path for the object to download the specified AWS file to, this path is controlled by the downloadPath method in 
    the S3RequestHelperDelegateProtocol.
 */
@property (nonatomic, readonly) NSString              *downloadPath;

/** Permanent file path for the object to be loaded to after it has been successfully downloaded to the downloadPath, this allows a
 complete set of files to be updated in a block, rather than updating some files and then having a failure and leaving the system
 half updated.
 */
@property (nonatomic, readonly) NSString              *persistPath;

/** Property containing the error object if thereis a failure during the download.
 */
@property (nonatomic, readonly) NSError               *error;

/** Property containing the exception object if there is an exception during the download. 
 */
@property (nonatomic, readonly) NSException           *exception;

// -------------------------------------------------------------------------------------------------
@end
