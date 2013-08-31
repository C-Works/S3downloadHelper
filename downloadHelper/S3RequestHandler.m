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
//#import <AWSS3/AWSS3.h>

@interface S3RequestHandler () <AmazonServiceRequestDelegate>
{
    int                     _attempts;
    
    float                   _downloadProgress;
    long long               _totalTransfered;
    long long               _expectedContentLength;
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
@synthesize status          = _status;

@synthesize response        = _response;
@synthesize error           = _error;
@synthesize exception       = _exception;
@synthesize delegate        = _delegate;
@synthesize S3ObjectSummary = _S3ObjectSummary;


-(id)initWithS3Obj:(S3ObjectSummary*)obj inBucket:(NSString*)bucket destPath:(NSString*)path withS3client:(AmazonS3Client*)client error:(NSError*)error
{
    self = [super init];
    if (self)
    {
        _S3ObjectSummary    = obj;
        _bucket             = bucket;
        _path               = path;
        _client             = client;
        _error              = error;
        
        _attempts           = 0;
        _status             = DOWNLOADING;
        
        [self tryDownload];
    }
    return self;
}

- (void)tryDownload{
    if(_outputStream != nil){
        [_outputStream close];
    }
    _response               = nil;
    _exception              = nil;
    _totalTransfered        = 0;
    _expectedContentLength  = 1;

    _attempts              += 1;
    _status                 = DOWNLOADING;

    _outputStream = [[ NSOutputStream alloc ] initToFileAtPath: _path append:NO ];
    [_outputStream open];
    
    _getObjectRequest   = [[S3GetObjectRequest alloc] initWithKey: _S3ObjectSummary.key withBucket: _bucket];
    _getObjectRequest.outputStream  = _outputStream;
    _getObjectRequest.delegate      = self;
    _getObjectResponse  = [_client getObject: _getObjectRequest];
}

-(void)cancelDownload{
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath: _path error: &error];
}

-(void)request:(AmazonServiceRequest *)request didReceiveResponse:(NSURLResponse *)aResponse{
    _expectedContentLength = aResponse.expectedContentLength;
}

-(void)request:(AmazonServiceRequest *)request didCompleteWithResponse:(AmazonServiceResponse *)aResponse
{
    // Close the stream, check there are no exceptions, if not set progress and status complete call the downloadFinished
    // method on the delegate. If exceptions report exceptions and delete the temporary file.
    NSError *error;
    [_outputStream close];

    if ( aResponse.exception == nil && [ request isKindOfClass:[ S3GetObjectRequest class ] ] ) {
        _downloadProgress = 1.0;
        _status           = COMPLETE;
        [_delegate downloadFinished: self];
    }
    else{
        _status = FAILED;
        [ _delegate downloadFailed: self WithException: aResponse.exception ];
        [[NSFileManager defaultManager] removeItemAtPath: _path error:&error];
    }
}

-(void)request:(AmazonServiceRequest *)request didReceiveData:(NSData *)data
{
    _totalTransfered += [data length];
    _downloadProgress = (float)_totalTransfered / (float)_expectedContentLength;
    NSLog(@"Progress: %f", _downloadProgress);
}

-(void)request:(AmazonServiceRequest *)request didFailWithError:(NSError *)theError
{
    // Close the streat, delete the failed download and report the failure.
    [_outputStream close];
    [[NSFileManager defaultManager] removeItemAtPath: _path error: &theError];
    [_delegate downloadFailed: self WithError: theError ];
}

-(void)request:(AmazonServiceRequest *)request didFailWithServiceException:(NSException *)theException
{
    // Close the streat, delete the failed download and report the failure.
    NSError *error;
    [_outputStream close];
    [[NSFileManager defaultManager] removeItemAtPath: _path error:&error];
    [_delegate downloadFailed: self WithException: _exception];
}



@end





