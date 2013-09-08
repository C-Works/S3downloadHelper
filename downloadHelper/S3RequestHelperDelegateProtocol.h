//
//  S3RequestHandlerDelegateProtocol.h
//  downloadHelper
//
//  Created by Jonathan Dring on 25/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import <Foundation/Foundation.h>

@class S3RequestHelper;


typedef enum{
    dhDOWNLOADING,
    dhSUSPENDED,
    dhCOMPLETE,
    dhINITIALISED
} SYNC_STATUS;


/** Protocol used by S3RequestHelper to communicate with the initiating Download or Sync Helper, to
    report changes of state to the file being downloaded.
 */
@protocol S3RequestHelperDelegateProtocol <NSObject>

@required

/** Return value tells the S3RequestHelper to stop or continue downloading the next block of data.
    Used to stop download attempts when there is no connection or the app is sent to background.
 */
- (BOOL)downloadEnable;

/** Return value is the location that the temporary download file is stored at until the download
 is persisted, this method is used to prevent a download over-writting an existing file until
 instructed. This path must include the complete path and the file name with extensions, the
 original file name can be obtained from the s3rh key property.
 */
- (NSString*)downloadPath:(S3RequestHelper*)s3rh;

/** Return value is the location that the temporary download file is persisted to when the persist
 method is called on the S3RequestObject. This path must include the complete path and the file
 name with extensions, the original file name can be obtained from the s3rh key property.
 */
- (NSString*)persistPath:(S3RequestHelper*)s3rh;

/** Methods used to validate that the file in the download location is valid against the checksum.
 */
- (BOOL)validateMD5forDownload:(S3RequestHelper*)s3rh;

/** Methods used to validate that the file in the persist location is valid against the checksum.
 */
- (BOOL)validateMD5forPersist:(S3RequestHelper*)s3rh;

/** Notifies the initiating helper that the download has completed successfully, and provides the
    pointer to the s3rh that has completed the download.
 */
- (void)downloadFinished:( S3RequestHelper * )s3rh;

/** Persistence method, has to move the file from download path to the place it will be validated
    by the validateMD5forPersist. These methods can be customised to un-zip files, or export data
    to another location etc.
 */
- (BOOL)persistFile:(S3RequestHelper*)s3rh;

/** Notifies the initiating helper that the download has failed, the details of the failure can be
    obtained from the error and exception properties of the S3RequestHelper passed. 
 */
- (void)downloadFailed:( S3RequestHelper * )s3rh;

@optional

/** Method called when the progress property of the S3RequestHelper increases by 1%.
 */
- (void)progressChanged:(S3RequestHelper*)s3rh;

@end
