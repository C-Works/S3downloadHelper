//
//  S#RequestHandler.m
//  S3downloadHelper
//
//  Created by Jonathan Dring on 12/02/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import "S3RequestHelper.h"
#import "S3SyncHelper.h"
#import <AWSRuntime/AWSRuntime.h>
#import <AWSS3/AmazonS3Client.h>

// ---------------------------------------------------------------------------------------------------------------------
// Module Definitions
// ---------------------------------------------------------------------------------------------------------------------
#define S3DH_RHANDLER_DOMAIN @"co.c-works.s3dh.requesthanlder"

// ---------------------------------------------------------------------------------------------------------------------
// Interface Definition
// ---------------------------------------------------------------------------------------------------------------------
@interface S3RequestHelper () <AmazonServiceRequestDelegate>
{
    AmazonS3Client          *_client;                   // S3 Client to use for handling requests.
    S3ObjectSummary         *_S3Summary;                // S3 Summary object defines the object to download.
    NSString                *_bucket;                   // S3 bucket name to download the object from.
    id <S3RequestHelperDelegateProtocol> _delegate;    // Delegate object to report back to.

    NSString                *_key;                      // S3 Object key extracted from S3Summary.
    NSString                *_md5;                      // S3 MD5 extracted from the S3Summary.

    NSString                *_downloadPath;             // Temporary file path to download file to.
    NSString                *_persistPath;              // Permanent file path to persist file to.
    NSOutputStream          *_outputStream;             // Filestream for the downloaded file request.

    int                     _attempts;                  // Counts failed attempts since last reset.
    int                     _progress;                  // Defines the current download progress 0-100%.
    REQUEST_STATE           _state;                     // Defines the download state of the object.
    Boolean                 _blockComplete;             // Indicates if the current block is complete or not.

    NSUInteger              _fileSize;                  // Filesize reported by Amazon for this file.
    NSUInteger              _dataTransfered;            // Total data streamed into the open file.
    NSUInteger              _blockRequestEnd;           // End of the last block requested.

    S3GetObjectRequest      *_getObjectRequest;         // Pointer to hold the active request for this download.

    NSError                 *_error;                    // Error, if reported by S3GetObjectRequest for this file.
    NSException             *_exception;                // Exception, if reported by the S3GetObjectRequest for this file.
}
@end

// ---------------------------------------------------------------------------------------------------------------------
// Class Implementation
// ---------------------------------------------------------------------------------------------------------------------
@implementation S3RequestHelper

// ---------------------------------------------------------------------------------------------------------------------
// Synthesized Getters & Setters
// ---------------------------------------------------------------------------------------------------------------------
@synthesize progress        = _progress;                // Synthesized to allow reporting of the status to the user.
@synthesize state           = _state;                   // Synthesized to allow the helper to determine next action.
@synthesize key             = _key;                     // Syntehsized to allow the helper to determine the file paths.
@synthesize md5             = _md5;                     // Syntehsized to allow the helper to validate downloads md5.

@synthesize persistPath     = _persistPath;
@synthesize downloadPath    = _downloadPath;

@synthesize error           = _error;                   // Synthesized to allow helper to make decisions about next action.
@synthesize exception       = _exception;               // Synthesized to allow helper to make decisions about next action.

// ---------------------------------------------------------------------------------------------------------------------
// Initialisation Methods
// ---------------------------------------------------------------------------------------------------------------------

// Initialisater, creates a new Request handler a prepares to start. Download begins when dowload is called.
-(id)initWithS3ObjectSummary:(S3ObjectSummary*)s S3Client:(AmazonS3Client*)c bucket:(NSString*)b  delegate:(id)d error:(NSError*)e
{
    self = [super init];

    if (self)
    {
        _error              = e;
        _state              = INITIALISED;
        
        if ( !( _client     = c ) ) {
            [self error:S3DH_RHANDLER_NIL_CLIENT data:nil error: &e ];
            return false;
        };

        if ( !( _bucket     = b ) ) {
            [self error:S3DH_RHANDLER_NIL_BUCKET data:b error: &e ];
            return false;
        }
        
        if ( !( _delegate   = d ) ) {
            [self error:S3DH_RHANDLER_NIL_DELEGATE data:nil error: &e ];
            return false;
        }
        
        if ( !( _S3Summary  = s ) ) {
            [self error:S3DH_RHANDLER_NIL_SUMMARY data:nil error: &e ];
            return false;
        };
        [self reset];
    }
    return self;
}


// ---------------------------------------------------------------------------------------------------------------------
// Public Control Methods
// ---------------------------------------------------------------------------------------------------------------------

// Reset will re-initialise the request from any state, delete all invalid files and prepare for re-start.
-(BOOL)reset{
    
    NSError *error;

    // Reset can be invoked from any object state and will delete all data and stop the download.
    _blockComplete          = YES;                              // Set block complete so first block download can start
    _getObjectRequest       = nil;                              // Clear any old request objectst objects.
    _attempts               = 0;                                // Reset the number of failed download attempts.
    _dataTransfered         = 0;                                // Reset the transfered data records.
    _blockRequestEnd        = 0;                                // Expected end of the last block request.
    _state                  = INITIALISED;                      // Reset the object to the default state.
    
    _key                    = _S3Summary.key;                   // Extract the file key from the S3Summary.
    _fileSize               = (NSInteger)_S3Summary.size;       // Extract the expected length from the S3Summary.

    _md5                   = [_S3Summary.etag stringByTrimmingCharactersInSet:
                              [NSCharacterSet characterSetWithCharactersInString:@"\""]];

    _downloadPath           = [_delegate downloadPath: self];   // Obtain the save file path from the helper object.
    _persistPath            = [_delegate persistPath:  self];   // Obtain the temporary file path from the helper object

    // Clean up and open streams, old files and check that the filepath is writtable.
    if (_outputStream != nil)   [_outputStream close];          // Close any open stream.
    

    if( [ _delegate validateMD5forPersist: self ] ){
        _state = SAVED;
        [[NSFileManager defaultManager] removeItemAtPath: _downloadPath error: &error];
        return true;
    }
    else if( [_delegate validateMD5forDownload:self] ){
        _state = TRANSFERED;

        if( ! [self createFolderForFilePath: _persistPath ] ){
            [self error:S3DH_RHANDLER_FOLDER_FAIL data:nil error: &error ];
            return false;
        }

        _state      = TRANSFERED;
        _progress   = 100;
        [_delegate downloadFinished: self];
        return true;
    }
    else{
        
        [[NSFileManager defaultManager] removeItemAtPath: _downloadPath error: &error];
        if( ! [self createFolderForFilePath: _downloadPath] ){
            [self error:S3DH_RHANDLER_FOLDER_FAIL data:nil error: &error ];
            return false;
        }
    }
    return true;
}


// Download will start or restart the download, if the bucket is reachable and downloads are enabled.
-(BOOL)download{

    NSError *error;
    
    if ( ! [_delegate downloadEnable] ) return false;
    if (!_blockComplete) return false;
    
    switch ( _state ) {
        case FAILED:        return false; break;
        case SAVED:         return false; break;
        case TRANSFERED:    return false; break;
        case DOWNLOADING:
            break;
        case INITIALISED:
            if( ! (_outputStream = [ [ NSOutputStream alloc ] initToFileAtPath: _downloadPath append: NO ] ) ){
                [self error:S3DH_RHANDLER_FILE_INIT_FAIL data:nil error: &error ];
                return false;
            }
            [_outputStream open];
            break;
        case SUSPENDED:
            if( ! (_outputStream = [ [ NSOutputStream alloc ] initToFileAtPath: _downloadPath append: YES ] ) ){
                [self error:S3DH_RHANDLER_FILE_STREAM_FAIL data:nil error: &error ];
                return false;
            }
            [_outputStream open];
            break;
    }

    _blockComplete      = NO;                           // Indicate that there is a block in progress.
    _state              = DOWNLOADING;                  // Show that the request has become an active download.

    // Calculate the end of the next block, and limit if it is beyond the end of file.
    _blockRequestEnd = DOWNLOAD_BLOCK_SIZE + _dataTransfered;
    if( _blockRequestEnd > (_fileSize - 1) )    _blockRequestEnd = _fileSize - 1;
    
    // Initialise an S# request object to fetch the data for this block.
    if ( !( _getObjectRequest = [[S3GetObjectRequest alloc] initWithKey: _key withBucket: _bucket] ) ){
        [self error:S3DH_RHANDLER_FILE_CREATE_FAIL data:nil error: &error ];
        return false;
    }
    _getObjectRequest.outputStream  = _outputStream;
    _getObjectRequest.delegate      = self;
    [_getObjectRequest setRangeStart: _dataTransfered  rangeEnd: _blockRequestEnd ];
    S3GetObjectResponse *getObjectResponse = [_client getObject: _getObjectRequest];
    
    // If the getObjectResponse has an error call interrupted download to handle and return false.
    if ( getObjectResponse.error != nil ){
        [self interruptedDownload];
        return false;
    }
    return true;
}

// Suspend a download that is in progress, used by the helper to stop downloading when connectivity is lost.
-(BOOL)suspend{

    // Return false if this is called when the state is not downloading.
    switch ( _state ) {
        case INITIALISED:   return false; break;
        case SUSPENDED:     return false; break;
        case FAILED:        return false; break;
        case TRANSFERED:    return false; break;
        case SAVED:         return false; break;
        case DOWNLOADING:   break;
    }

    // Stop the download object, close filestream and set state suspended.
    _getObjectRequest   = nil;
    [_outputStream close];
    _state              = SUSPENDED;
    _attempts           = 0;
    return true;
}

// Save the file if the transfer completed successfully, allows the helper to synchronise persisting of data.
-(BOOL)persist{

    switch ( _state ) {
        case INITIALISED:   return false; break;
        case SUSPENDED:     return false; break;
        case FAILED:        return false; break;
        case DOWNLOADING:   return false; break;
        case SAVED:         return false; break;
        case TRANSFERED:    break;
    }
    
    if( ! [_delegate persistFile:self] ) {
        NSString *data = [[NSString alloc] initWithFormat:@"[Download:%@] [Persist:%@]", _downloadPath, _persistPath ];
        [self error: S3DH_RHANDLER_FILE_PERSIST_FAIL data: data error: nil ];
        return false;
    }
    _state = SAVED;
    return true;
}

// ---------------------------------------------------------------------------------------------------------------------
// Support Methods
// ---------------------------------------------------------------------------------------------------------------------
// Creates the folder path for a specified file path.
-(BOOL)createFolderForFilePath:(NSString*)path{

    NSError *error;
    
    if( !path ) return false;
        
    NSMutableArray *splitPath = (NSMutableArray*)[path componentsSeparatedByString:@"/"];
    [splitPath removeLastObject];
    NSString *folderPath = [splitPath componentsJoinedByString:@"/"];
    
    NSFileManager *fManager = [NSFileManager defaultManager];
    if(!([fManager createDirectoryAtPath: folderPath withIntermediateDirectories:YES attributes:nil error: &error])){
        return false;
    }
    return true;
}

// ---------------------------------------------------------------------------------------------------------------------
// PROTOCOL Methods - Amazon Service Request Delegate
// ---------------------------------------------------------------------------------------------------------------------
// Counts received bytes of data, when the is stream open, loaded into the file to determine next block start.
-(void)request:(AmazonServiceRequest *)request didReceiveData:(NSData *)data{

    int progress;
    
    if( _state == DOWNLOADING && [ request isKindOfClass:[ S3GetObjectRequest class ] ] ){
        _dataTransfered += [data length];

        if( _fileSize == 0.0 || _dataTransfered == 0.0)    progress = 0;
        else   progress = (_dataTransfered * 100)/ _fileSize;
        
        Boolean didChange = ( progress != _progress );
        _progress = progress;

        if ( didChange && [_delegate respondsToSelector:@selector(progressChanged:)]){
            [_delegate progressChanged: self];
        }
    }
}

// Method handles end-of-block & either restarts or checks the md5 and sets the state to TRANSFERED.
-(void)request:(AmazonServiceRequest *)request didCompleteWithResponse:(AmazonServiceResponse *)aResponse{
    
    Boolean validRequest = [ request isKindOfClass:[ S3GetObjectRequest class ] ];
    Boolean validMD5     = [ _delegate validateMD5forDownload: self ];
    Boolean noException  = ( aResponse.exception == nil );
    
    // Set block complete flag to allow download to start the next block.
    _blockComplete       = YES;
    
    // If the file lenght exceeds the AWS filesize, report error and fail download.
    if( _blockRequestEnd > (_fileSize - 1) ){
        [self error: S3DH_RHANDLER_FILE_PERSIST_FAIL data: _key error: nil ];
    }
    
    // If the helper is disabled, or bucket unreachable, suspend download.
    if( ![ _delegate downloadEnable ] ) {
        [self suspend];
    
    }else{
        // Determine the download action for each request state.
        switch ( _state ) {
            case SUSPENDED:
            case DOWNLOADING:
                // If the Handler is downloading, restart the next block.
                if( _blockRequestEnd < (_fileSize - 1) ){
                    [self download];
                }
                else if( noException && validRequest && validMD5 ){
                    _state              = TRANSFERED;
                    _getObjectRequest   = nil;
                    _progress   = 100;
                    [_outputStream close];
                    [_delegate downloadFinished: self];
                }
                else{
                    // Download completed but with an error, exception or invalid md5.
                    [self error: S3DH_RHANDLER_DOWNLOAD_ERROR data: _key error: nil ];
                }
                break;
            case INITIALISED:        break;
            case TRANSFERED:         break;
            case SAVED:              break;
            case FAILED:             break;
        }
    }
}

-(void)request:(AmazonServiceRequest *)request didFailWithError:(NSError *)theError{
    if( [ request isKindOfClass:[ S3GetObjectRequest class ] ] ){
        _error = theError;
        [self interruptedDownload];
    }
}

-(void)request:(AmazonServiceRequest *)request didFailWithServiceException:(NSException *)theException{
    if( [ request isKindOfClass:[ S3GetObjectRequest class ] ] ){
        _exception = theException;
        [self interruptedDownload];
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// PROTOCOL - Support Methods
// ---------------------------------------------------------------------------------------------------------------------

// If the download is interrupted, this method determines if it should be suspended, reported or re-started.
-(void)interruptedDownload{
    // if the connection is working check how many attempts
    if ( [_delegate downloadEnable] ){
        // If retrys is below threshold try again.
        if ( _attempts < DEFAULT_RETRY_LIMIT ){
            // Re-start the dwonload and count the attempt.
            [self download];
            _attempts ++;
        }
        // If retrys is above threshold report failure.
        else{
            [self error: S3DH_RHANDLER_RETRY_EXCEEDED data: _key error: nil ];
        }
    }
    // If un-reachable, suspend the download.
    else{
        [ self suspend ];
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// Error Message Generation
// ---------------------------------------------------------------------------------------------------------------------
- (void) error:(int)code data:(NSString*)data error:(NSError**)errorp
{
    NSMutableString *errorDesc = [[NSMutableString alloc]init];
    
    switch (code)
    {
        case S3DH_RHANDLER_NIL_CLIENT:        [ errorDesc appendString: @"Init with null client." ];    break;
        case S3DH_RHANDLER_NIL_BUCKET:        [ errorDesc appendString: @"Init with null bucket." ];    break;
        case S3DH_RHANDLER_NIL_DELEGATE:      [ errorDesc appendString: @"Init with null delegate." ];  break;
        case S3DH_RHANDLER_NIL_SUMMARY:       [ errorDesc appendString: @"Init with null summary." ];   break;
        case S3DH_RHANDLER_FILE_UNWRITABLE:   [ errorDesc appendString: @"Filepath unwrittable:" ];     break;
        case S3DH_RHANDLER_FILE_CREATE_FAIL:  [ errorDesc appendString: @"File creation failure:" ];    break;
        case S3DH_RHANDLER_FOLDER_FAIL:       [ errorDesc appendString: @"Folder creation fail:" ];     break;
        case S3DH_RHANDLER_FILE_STREAM_FAIL:  [ errorDesc appendString: @"Stream open fail:" ];         break;
        case S3DH_RHANDLER_FILE_PERSIST_FAIL: [ errorDesc appendString: @"File Persist Fail:" ];        break;
        case S3DH_RHANDLER_FILE_DL_OVERRUN:   [ errorDesc appendString: @"Download over-ran:" ];        break;
        case S3DH_RHANDLER_DOWNLOAD_ERROR:    [ errorDesc appendString: @"Download with error:" ];      break;
        case S3DH_RHANDLER_RETRY_EXCEEDED:    [ errorDesc appendString: @"Exceeded Retry Limit:" ];     break;
        default:                              [ errorDesc appendString: @"No reported errors! "  ];     break;
    }
    
    NSMutableDictionary *userInfo = [[ NSMutableDictionary alloc ] init ];
    
    if ( data ) [ errorDesc appendFormat:@"{%@}. ", data ];
    if( errorp ) {
        if ( [ *errorp userInfo ] )[ userInfo setDictionary: [ *errorp userInfo ] ];
        if ( [ *errorp localizedDescription ] ) [ errorDesc appendString: [ *errorp localizedDescription ] ];
    }
    
    [userInfo setObject: errorDesc forKey: NSLocalizedDescriptionKey ];
    
    *errorp = [ NSError  errorWithDomain: S3DH_RHANDLER_DOMAIN code:code userInfo:userInfo ];
    
    // Clean up the object and downloads.
    _error              = *errorp;
    _state              = FAILED;
    _getObjectRequest   = nil;
    _progress           = 0.0;
    [_outputStream close];
    [_delegate downloadFailed: self ];
}
// ---------------------------------------------------------------------------------------------------------------------

@end





