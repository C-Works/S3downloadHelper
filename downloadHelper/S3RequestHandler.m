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
    NSUInteger              _dataBlock;
    NSUInteger              _currentRangeEnd;
    NSString                *_path;
    
    S3GetObjectRequest      *_getObjectRequest;
    S3GetObjectResponse     *_getObjectResponse;
    S3ObjectSummary         *_S3ObjectSummary;
    AmazonS3Client          *_client;
    NSString                *_bucket;
    
    AmazonServiceResponse   *_response;
    NSException             *_exception;
    NSError                 *_error;
    
    NSOutputStream          *_outputStream;
}
@end



@implementation S3RequestHandler


@synthesize attempts        = _attempts;
@synthesize response        = _response;
@synthesize error           = _error;
@synthesize exception       = _exception;
@synthesize delegate        = _delegate;
@synthesize S3ObjectSummary = _S3ObjectSummary;
@synthesize state           = _state;

-(id)initWithS3Obj:(S3ObjectSummary*)obj inBucket:(NSString*)bucket destPath:(NSString*)path withS3client:(AmazonS3Client*)client error:(NSError*)error
{
    self = [super init];

    if (self)
    {
        _S3ObjectSummary        = obj;
        _client                 = client;
        _bucket                 = bucket;
        _error                  = error;
        _path                   = path;
        
        _expectedContentLength  = (NSInteger)_S3ObjectSummary.size;
        _totalTransfered        = 0;
        
        _currentRangeEnd        = 0;
        
        _attempts               = 0;
        _dataBlock              = 0;
        
        _outputStream = [[ NSOutputStream alloc ] initToFileAtPath: _path append: NO ];
        [_outputStream open];

        _state                 = INITIALISED;
    }
    return self;
}

- (BOOL)tryDownload{

    // Confirm that the delegate has been set before downloading.
    if ( ! _delegate ) return false;
    
    // Exit if the handler is downloading or complete, if complete reset first.
    if( _state == DOWNLOADING || _state == COMPLETE || _state == SUSPENDED ) {
        
        return false;
    }
    
    // FAILED, SUSPENDED, CANCELLED, INITIALISED:
    
    _response               = nil;
    _exception              = nil;
    
    if ( [_delegate isReachable]){

        [self fetchDataBlock];
    }
    return true;
}

-(void)fetchDataBlock{

    if( _state == SUSPENDED )
    {
        _outputStream = [[ NSOutputStream alloc ] initToFileAtPath: _path append: YES ];
        [_outputStream open];
    }
    _state  = DOWNLOADING;


    NSUInteger BLOCK_SIZE = 1024 * 256;
    
    NSUInteger start = _totalTransfered;
//    NSUInteger start = _dataBlock * ( BLOCK_SIZE + 1 );
    _currentRangeEnd = BLOCK_SIZE + start;
    
    if( _currentRangeEnd > (_expectedContentLength - 1) )
    {
        _currentRangeEnd = _expectedContentLength - 1;
    }
    
    NSLog(@"Block Start: %d End: %d delta:%d", start, _currentRangeEnd, (_currentRangeEnd - start) );
    
    _getObjectRequest   = [[S3GetObjectRequest alloc] initWithKey: _S3ObjectSummary.key withBucket: _bucket];
    
    _getObjectRequest.outputStream  = _outputStream;
    _getObjectRequest.delegate      = self;
    
    [_getObjectRequest setRangeStart: start  rangeEnd: _currentRangeEnd ];
    
    _getObjectResponse  = [_client getObject: _getObjectRequest];

    
}

-(void)request:(AmazonServiceRequest *)request didReceiveData:(NSData *)data{
    if( _state == DOWNLOADING ){
        _totalTransfered += [data length];
        NSLog(@"Block Data: %d", _totalTransfered - 1);
    }
}

-(void)request:(AmazonServiceRequest *)request didCompleteWithResponse:(AmazonServiceResponse *)aResponse
{
    // Close the stream, check there are no exceptions, if not set progress and status complete call the downloadFinished
    // method on the delegate. If exceptions report exceptions and delete the temporary file.

    Boolean validRequest = [ request isKindOfClass:[ S3GetObjectRequest class ] ];
    Boolean validMD5     = [ downloadHelper validateMD5forSummary:_S3ObjectSummary withPath: _path ];
    Boolean noException  = ( aResponse.exception == nil );
    
    NSUInteger stopLimit = _expectedContentLength - 1;
    
    if ( _currentRangeEnd < stopLimit ){
        _dataBlock++;
        [self fetchDataBlock];
    }
    else if ( _state == SUSPENDED )
    {
        NSLog(@"Suspended");
    }
    else if (  noException && validRequest && validMD5 ){
        NSLog(@"S3 MD5:%@", _S3ObjectSummary.etag);
        NSLog(@"FP MD5:%@", [downloadHelper fileMD5: _path]);
        [self downloadComplete];
    }
    else{
        
        NSLog(@"S3 MD5:%@", _S3ObjectSummary.etag);
        NSLog(@"FP MD5:%@", [downloadHelper fileMD5: _path]);
        [_outputStream close];
        [self failedDownload];
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
            [self tryDownload];
            _attempts ++;
        }
        // If retrys is above threshold report failure.
        else{
            [ self failedDownload ];
        }
    }
    // If un-reachable, suspend the download.
    else{
        NSLog(@"[INTERRUPTED]:%@", _S3ObjectSummary.key );
        [ self suspendDownload ];
    }
}


-(void)suspendDownload{
    _getObjectRequest = nil;
    [_outputStream close];
    _state = SUSPENDED;
    _attempts = 0;
}

-(void)cancelDownload{
    [self resetDownload];
    _state = CANCELLED;
}

-(void)failedDownload{
    [self resetDownload];
    _state = FAILED;
    [_delegate downloadFailed: self ];
}

-(void)resetDownload{
    NSError *error;
    _getObjectRequest       = nil;
    _attempts               = 0;
    _totalTransfered        = 0;
    [_outputStream close];
    [[NSFileManager defaultManager] removeItemAtPath: _path error: &error];
    _outputStream = [[ NSOutputStream alloc ] initToFileAtPath: _path append: NO ];
    [_outputStream open];

}


-(void)downloadComplete{
    _downloadProgress       = 1.0;
    _state                  = COMPLETE;
    _getObjectRequest       = nil;
    [_outputStream close];
    [_delegate downloadFinished: self];
}


@end





