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
#import <AWSS3/AWSS3.h>

@interface S3RequestHandler () <AmazonServiceRequestDelegate>
{
    float                   _downloadProgress;
    long long               _expectedContentLength;
    NSMutableData           *_downloadData;
    NSString                *_filePathToSaveTo;
    
    
    S3GetObjectRequest      *_getObjectRequest;
    S3GetObjectResponse     *_getObjectResponse;
    S3ObjectSummary         *_object;
    AmazonS3Client          *_client;
    NSString                *_bucket;
    
    AmazonServiceResponse   *_response;
    NSException             *_exception;
    NSError                 *_error;
}
@end

@implementation S3RequestHandler

@synthesize response    = _response;
@synthesize error       = _error;
@synthesize exception   = _exception;
@synthesize delegate    = _delegate;

-(id)initWithS3Obj:(S3ObjectSummary*)obj inBucket:(NSString*)bucket destPath:(NSString*)path withS3client:(AmazonS3Client*)client error:(NSError*)error
{
    self = [super init];
    if (self)
    {
        _response  = nil;
        _exception = nil;
        _downloadData = [[NSMutableData alloc]init];
        _filePathToSaveTo = path;
        _bucket = bucket;
        _object = obj;
        _client = client;
        _error = error;
        
        _getObjectRequest = [[S3GetObjectRequest alloc] initWithKey: _object.key withBucket: _bucket];
        [_getObjectRequest setDelegate: self ];
        
        //When using delegates the return is nil.
        _getObjectResponse = [_client getObject: _getObjectRequest];
    }
    return self;
}

-(bool)isFinishedOrFailed
{
    return (_response != nil || _error != nil || _exception != nil);
}

-(void)request:(AmazonServiceRequest *)request didReceiveResponse:(NSURLResponse *)aResponse
{
    _expectedContentLength = aResponse.expectedContentLength;
}

-(void)request:(AmazonServiceRequest *)request didCompleteWithResponse:(AmazonServiceResponse *)aResponse
{
    if (aResponse.exception == nil) {
        if ( [ request isKindOfClass:[ S3GetObjectRequest class ] ] ) {
            [_downloadData writeToFile: _filePathToSaveTo atomically:YES];
            _downloadProgress = 1.0;
            _downloadData = nil;
        }
    }

    [_delegate downloadComplete:self];

}

-(void)request:(AmazonServiceRequest *)request didReceiveData:(NSData *)data
{
    [ _downloadData appendData: data];
    _downloadProgress = (float)[ _downloadData length] / (float)_expectedContentLength;
    NSLog(@"Progress: %f", _downloadProgress);

}


-(void)request:(AmazonServiceRequest *)request didFailWithError:(NSError *)theError
{
    _error = theError;
    NSLog(@"didFailWithError : %@", _error.localizedDescription);
    [_delegate downloadFailedWithError: _error];
}

-(void)request:(AmazonServiceRequest *)request didFailWithServiceException:(NSException *)theException
{
    _exception = theException;
    NSLog(@"didFailWithServiceException : %@", _exception);
    [_delegate downloadFailedWithException: _exception];
}


-(void)saveDataToFile{

    if(true){
        [_downloadData writeToFile: _filePathToSaveTo atomically:YES];
    }
}

@end





