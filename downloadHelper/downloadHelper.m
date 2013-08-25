//
//  downloadHelper.m
//  downloadHelper
//
//  Created by Jonathan Dring on 24/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import "downloadHelper.h"
#import "S3ResponseHandler.h"


@implementation downloadHelper
{
    AmazonS3Client      *_s3;
    NSString            *_bucket;
    NSMutableData       *_downloadData;
    NSString            *_filePathToSaveTo;
    float               _downloadProgress;
    long long           _expectedContentLength;
    S3ResponseHandler   *_s3ResponseHandler;
    S3GetObjectRequest  *_getObjectRequest;
    S3GetObjectResponse *_getObjectResponse;
}

- (id)initWithBucket:(NSString*)bucket
{
    self = [super init];
    if( self ){

        _s3 = [[AmazonS3Client alloc] initWithAccessKey:dhKey withSecretKey: dhSec];
        //_s3.timeout = 10000;
        _s3.endpoint = [AmazonEndpoints s3Endpoint: EU_WEST_1 ];

        
        if ( ! _s3 ) return nil;
        if ( ! bucket ) return nil;
        _bucket = bucket;
    }
    return self;
}

-(void) synchroniseBucket{

    NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0 ];
    NSFileManager *fileManager = [NSFileManager defaultManager];//[[NSFileManager alloc] init];
    NSString *filePath;
    NSError *error;
    BOOL isDir;
    BOOL pathExists;
    
    NSArray *objects = [_s3 listObjectsInBucket: _bucket ];

    //for( S3ObjectSummary *o in objects){
        
    S3ObjectSummary *o = [objects objectAtIndex:1];
     
        filePath = [root stringByAppendingPathComponent: o.key ];
        
        pathExists = [fileManager fileExistsAtPath: filePath isDirectory: &isDir ];

        // Object is a folder...
        if ( [o.key hasSuffix: @"/" ]  ){

            if( pathExists && !isDir ){
                // This folder exists as a file, it should be deleted...
                
            }
            else if( !pathExists ){
                // The folder doesn't exist so should be created...
                [fileManager createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:&error ];
            }
            else{
                // The folder exists already...
            }
        
        }// Object is a file
        else{

            if( pathExists && isDir ){
                // This file is a folder, need to delete.
                NSLog(@"isDirectory");
            }
            else if( !pathExists ){

                //Create file on the S3 folder..

                
                [AmazonLogger verboseLogging];

                _s3ResponseHandler = [[S3ResponseHandler alloc] init];
                _getObjectRequest = [[S3GetObjectRequest alloc] initWithKey: o.key withBucket: _bucket];
                [_getObjectRequest setDelegate: _s3ResponseHandler];
                
                //When using delegates the return is nil.
                _getObjectResponse = [_s3 getObject: _getObjectRequest];

                NSLog(@"Error: %@", _getObjectResponse.error.localizedDescription);
                
//                [self downloadKey:o.key];
//                _filePathToSaveTo = [root stringByAppendingPathComponent: @"test.png" ];
            
            }
            else if( !( [[ self objectS3eTag: o ] isEqualToString:[ downloadHelper fileMD5: filePath ] ] ) ){
                // File exists but the MD5 has changed on the bucket, need to update...

//                [self downloadKey:o.key];
//                _filePathToSaveTo = filePath;
            }
        }
    //}
    
}


-(void) downloadKey:(NSString*)key{
    
    _getObjectRequest = [[S3GetObjectRequest alloc ] initWithKey: key withBucket: _bucket ];
    [_getObjectRequest setDelegate: self];
    _downloadData = [ [ NSMutableData alloc ] init ];
    _getObjectResponse = [_s3 getObject: _getObjectRequest];
    NSLog(@"Error: %@", _getObjectResponse.error.localizedDescription);
}



// ---------------------------------------------------------------------------------------------------------------------

-(void)request:(AmazonServiceRequest *)request didFailWithError:(NSError *)error{
    NSLog(@"%@", error.localizedDescription);
}

-(void)request:(AmazonServiceRequest *)request didFailWithServiceException:(NSException *)theException{
    NSLog(@"didFailWithServiceException : %@", theException);
}

-(void)request:(AmazonServiceRequest *)request didReceiveResponse:(NSURLResponse *)response{
    _expectedContentLength = response.expectedContentLength;
}

-(void)request:(AmazonServiceRequest *)request didCompleteWithResponse:(AmazonServiceResponse *)response{
    if (response.exception == nil) {
        if ([request isKindOfClass:[S3GetObjectRequest class]]) {
            [_downloadData writeToFile: _filePathToSaveTo atomically:YES];
            _downloadProgress = 1.0;
            _downloadData = nil;
        }
    }
}

-(void)request:(AmazonServiceRequest*)request didReceiveData:(NSData*)data{
    [ _downloadData appendData: data];
    _downloadProgress = (float)[ _downloadData length] / (float)_expectedContentLength;
    NSLog(@"Progress: %f", _downloadProgress);
}

// ---------------------------------------------------------------------------------------------------------------------
- (NSString*)objectS3eTag:(S3ObjectSummary*)object{
    
    NSString *s;
    NSString *eTag;
    
    eTag = object.etag;
        
    s = [eTag stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString:@"\""]];
    
    return s;
}


+(NSString*)fileMD5:(NSString*)path
{
	NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
	
	CC_MD5_CTX md5;
	CC_MD5_Init(&md5);
	
    if(handle != nil){
        BOOL done = NO;
        while(!done)
        {
            @autoreleasepool {
                NSData* fileData = [handle readDataOfLength: CHUNK_SIZE ];
                CC_MD5_Update(&md5, [fileData bytes], [fileData length]);
                if( [fileData length] == 0 ) done = YES;
            }
        }
    }
	unsigned char digest[CC_MD5_DIGEST_LENGTH];
	CC_MD5_Final(digest, &md5);
	NSString* s = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
				   digest[0], digest[1],
				   digest[2], digest[3],
				   digest[4], digest[5],
				   digest[6], digest[7],
				   digest[8], digest[9],
				   digest[10], digest[11],
				   digest[12], digest[13],
				   digest[14], digest[15]];
	return s;
}


@end
