//
//  S3DownloadHelper.m
//  downloadHelper
//
//  Created by Jonathan Dring on 10/09/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import "S3DownloadHelper.h"
#import "S3SyncHelper.h"
#import "S3AsyncHelper.h"
#import "S3RequestHelperDelegateProtocol.h"


@interface S3DownloadHelper()
{
    
}
@end

@implementation S3DownloadHelper




+(S3SyncHelper*)syncHelperWithS3Client:(AmazonS3Client*)c forBucket:(NSString*)b delegate:(id)d{
//    return [[S3SyncHelper alloc ] initWithS3Client:c forBucket:b];

}



+(S3AsyncHelper*)asyncHelperWithS3Client:(AmazonS3Client*)c forBucket:(NSString*)b delegate:(id)d{
//    return [[S3AsyncHelper alloc ] initWithS3Client:c forBucket:(NSString*)bucket];
    
}







@end
