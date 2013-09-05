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

#import "S3RequestHandler.h"
#import <AWSRuntime/AWSRuntime.h>
#import <AWSS3/AmazonS3Client.h>


@interface S3RequestHandler () <AmazonServiceRequestDelegate>
{
    int                     _attempts;
    REQUEST_STATE           _state;
    
    float                   _downloadProgress;
    NSUInteger              _totalTransfered;
    NSUInteger              _expectedContentLength;
    NSUInteger              _currentRangeEnd;
    NSString                *_path;
    
    S3GetObjectRequest      *_getObjectRequest;
    S3GetObjectResponse     *_getObjectResponse;
    S3ObjectSummary         *_S3Summary;
    AmazonS3Client          *_client;
    NSString                *_bucket;
    NSString                *_key;
    NSString                *_eTag;
    
    AmazonServiceResponse   *_response;
    NSException             *_exception;
    NSError                 *_error;
    
    NSOutputStream          *_outputStream;
    
    BOOL                    *_blockComplete;
    
}
@end



@implementation S3RequestHandler


@synthesize attempts        = _attempts;
@synthesize response        = _response;
@synthesize error           = _error;
@synthesize exception       = _exception;
@synthesize delegate        = _delegate;
@synthesize S3ObjectSummary = _S3Summary;
@synthesize state           = _state;
@synthesize eTag            = _eTag;

-(id)initWithS3Obj:(S3ObjectSummary*)obj inBucket:(NSString*)bucket destPath:(NSString*)path withS3client:(AmazonS3Client*)client error:(NSError*)error
{
    self = [super init];

    if (self)
    {
        _state                  = INITIALISED;
        _S3Summary              = obj;
        _path                   = path;
        _error                  = error;
        _client                 = client;
        _bucket                 = bucket;           // Copy init variables in.
        [ self reset ];                             // Initialise all variables and copy data from S3Summary.
    }
    return self;
}


-(void)request:(AmazonServiceRequest *)request didReceiveData:(NSData *)data{
    if( _state == DOWNLOADING ){
        _totalTransfered += [data length];
        NSLog(@"Block Data: %d", _totalTransfered - 1);
    }
    else{
        NSLog(@"Data recieved but not saved", _totalTransfered - 1);
    }
}

-(void)request:(AmazonServiceRequest *)request didCompleteWithResponse:(AmazonServiceResponse *)aResponse
{
    // Close the stream, check there are no exceptions, if not set progress and status complete call the downloadFinished
    // method on the delegate. If exceptions report exceptions and delete the temporary file.

    Boolean validRequest = [ request isKindOfClass:[ S3GetObjectRequest class ] ];
    Boolean validMD5     = [ downloadHelper validateMD5forSummary: _S3Summary withPath: _path ];
    Boolean noException  = ( aResponse.exception == nil );
    
    NSUInteger stopLimit = _expectedContentLength - 1;

    NSLog(@"Block Complete");

    if ( _state == SUSPENDED ){

        [self download];
        NSLog(@"Suspended - No restart");
    
    } else if ( _currentRangeEnd < stopLimit ){
        NSLog(@"End not reached - Start NExt Block");
        _state  = BLOCKCOMPLETE;
        [self download];
    }
    else if (  noException && validRequest && validMD5 ){
        NSLog(@"S3 MD5:%@", _eTag );
        NSLog(@"FP MD5:%@", [downloadHelper fileMD5: _path]);
        _state              = TRANSFERED;
        _getObjectRequest   = nil;
        [_outputStream close];
        _downloadProgress   = 1.0;
        [_delegate downloadFinished: self];
    }
    else{
        
        NSLog(@"S3 MD5:%@", _eTag );
        NSLog(@"FP MD5:%@", [downloadHelper fileMD5: _path]);
        _state              = FAILED;
        _getObjectRequest   = nil;
        [_outputStream close];
        [_delegate downloadFailed: self ];
    }
}


-(void)request:(AmazonServiceRequest *)request didFailWithError:(NSError *)theError{
    _error = theError;
    [self interruptedDownload];
}

-(void)request:(AmazonServiceRequest *)request didFailWithServiceException:(NSException *)theException{
    _exception = theException;
    [self interruptedDownload];
}

-(void)interruptedDownload{
    // if the connection is working check how many attempts
    if ( _delegate.isReachable ){
        // If retrys is below threshold try again.
        if ( _attempts < DEFAULT_RETRY_LIMIT ){
            [self download];
            _attempts ++;
        }
        // If retrys is above threshold report failure.
        else{
            _state              = FAILED;
            _getObjectRequest   = nil;
            [_outputStream close];
            [_delegate downloadFailed: self ];
        }
    }
    // If un-reachable, suspend the download.
    else{
        NSLog(@"[INTERRUPTED]:%@", _key );
        [ self suspend ];
    }
}

// ---------------------------------------------------------------------------------------------------------------------
// STATE Machine Controls
-(BOOL)reset{
    NSError *error;
    switch ( _state ) {
        case SUSPENDED:     return false; break;
        case FAILED:        return false; break;
        case INITIALISED:   break;
        case DOWNLOADING:   break;
        case BLOCKCOMPLETE: break;
        case TRANSFERED:    break;
        case SAVED:         break;
    }

    _getObjectRequest       = nil;                              // Clear the request object.
    _attempts               = 0;                                // Reset the number of failed attempts.
    _totalTransfered        = 0;                                // Reset the transfered data records.
    _currentRangeEnd        = 0;                                // Expected end of the last block request.
    _state                  = INITIALISED;                      // Reset the object to the default state.
    
    _expectedContentLength  = (NSInteger)_S3Summary.size; // Reoad the expected length.
    _key                    = _S3Summary.key;
    _eTag                   = [_S3Summary.etag stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@"\""]];
    
    if (_outputStream != nil)   [_outputStream close];                      // Close any open stream.
    [[NSFileManager defaultManager] removeItemAtPath: _path error: &error];
    
    return true;
}

-(BOOL)save{
    switch ( _state ) {
        case INITIALISED:   return false; break;
        case SUSPENDED:     return false; break;
        case FAILED:        return false; break;
        case DOWNLOADING:   return false;break;
        case BLOCKCOMPLETE: return false;break;
        case SAVED:         return false;break;
        case TRANSFERED:    break;
    }
    // Code implementation needs to save the temporary file.
}

-(BOOL)download{
    NSLog(@"DOWNLOAD - Start");

    // Confirm the object has a delegate and the host is reachable.
    if ( ! _delegate )      return false;
    if ( ! _delegate.isReachable ) return false;
    
    switch ( _state ) {
        case FAILED:        return false; break;
        case TRANSFERED:    return false; break;
        case SAVED:         return false; break;
        case DOWNLOADING:   return false; break;

        case BLOCKCOMPLETE:
            break;
        case INITIALISED:
            _outputStream = [[ NSOutputStream alloc ] initToFileAtPath: _path append: NO ];
            [_outputStream open];
            break;
        case SUSPENDED:
            _outputStream = [[ NSOutputStream alloc ] initToFileAtPath: _path append: YES ];
            [_outputStream open];
            break;
    }

    _state              = DOWNLOADING;

    NSUInteger start = _totalTransfered;
    
    _currentRangeEnd = DOWNLOAD_BLOCK_SIZE + start;
    
    if( _currentRangeEnd > (_expectedContentLength - 1) )    {
        _currentRangeEnd = _expectedContentLength - 1;
    }
    
    NSLog(@"Block Start: %d End: %d delta:%d", start, _currentRangeEnd, (_currentRangeEnd - start) );
    
    _getObjectRequest   = [[S3GetObjectRequest alloc] initWithKey: _key withBucket: _bucket];
    _getObjectRequest.outputStream  = _outputStream;
    _getObjectRequest.delegate      = self;
    [_getObjectRequest setRangeStart: start  rangeEnd: _currentRangeEnd ];
    _getObjectResponse  = [_client getObject: _getObjectRequest];
    NSLog(@"DOWNLOAD - End");

}

-(BOOL)suspend{
    NSLog(@"SUSPEND - Start");
    switch ( _state ) {
        case INITIALISED:   return false; break;
        case SUSPENDED:     return false; break;
        case FAILED:        return false; break;
        case TRANSFERED:    return false; break;
        case SAVED:         return false; break;
        case DOWNLOADING:   break;
        case BLOCKCOMPLETE: break;
    }
    _getObjectRequest   = nil;
    [_outputStream close];
    _state              = SUSPENDED;
    _attempts           = 0;
    NSLog(@"SUSPEND - End");
}

// ---------------------------------------------------------------------------------------------------------------------

@end





