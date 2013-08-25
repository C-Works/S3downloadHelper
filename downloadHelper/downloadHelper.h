//
//  downloadHelper.h
//  downloadHelper
//
//  Created by Jonathan Dring on 24/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AWSRuntime/AWSRuntime.h>
#import <AWSS3/AmazonS3Client.h>
#import <AWSS3/AWSS3.h>


#import <CommonCrypto/CommonDigest.h>
#import "Constants.h"


#define CHUNK_SIZE 100000


@interface downloadHelper : NSObject <AmazonServiceRequestDelegate>


- (id) initWithBucket:(NSString*)bucket;
- (void) synchroniseBucket;


//-(void)request:(AmazonServiceRequest*)request didFailWithError:(NSError*)error;
//-(void)request:(AmazonServiceRequest*)request didFailWithServiceException:(NSException*)theException;
//-(void)request:(AmazonServiceRequest*)request didReceiveResponse:(NSURLResponse*)response;
//-(void)request:(AmazonServiceRequest*)request didCompleteWithResponse:(AmazonServiceResponse*)response;
//-(void)request:(AmazonServiceRequest*)request didReceiveData:(NSData*)data;

@end
