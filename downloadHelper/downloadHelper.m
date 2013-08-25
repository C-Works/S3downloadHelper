//
//  downloadHelper.m
//  downloadHelper
//
//  Created by Jonathan Dring on 24/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import "downloadHelper.h"

@implementation downloadHelper

static downloadHelper *_sharedInstance;

#pragma mark -
#pragma mark Singleton Methods

+ (downloadHelper*)sharedInstance {
    @synchronized(self){
        if(_sharedInstance == nil) {
            [self allocWithZone:nil];
            
        }
    }
    return _sharedInstance;
}

+ (id)alloc{
    return _sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
    
    // If no registry, use threadsafe method to create.
    if( ! _sharedInstance ){
        static dispatch_once_t oncePredicate;
        dispatch_once(&oncePredicate, ^{
            _sharedInstance = [[super allocWithZone:nil] init];
        });
    }
    return _sharedInstance;
}

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#if (!__has_feature(objc_arc))

- (id)retain {
    
	return self;
}

- (unsigned)retainCount {
	return UINT_MAX;  //denotes an object that cannot be released
}

- (void)release {
	//do nothing
}

- (id)autorelease {
	return self;
}
#endif

#pragma mark -
#pragma mark Persistence Methods



-(void) updateApplicationFilesInBucket:(NSString*)bucket{

    NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0 ];
    NSFileManager *fileManager = [NSFileManager defaultManager];//[[NSFileManager alloc] init];
    NSString *path;
    NSError *error;
    NSMutableArray *requestQueue;
    BOOL isDir;
    BOOL pathExists;
    S3Request *request;
    
    AmazonS3Client *s3 = [[AmazonS3Client alloc] initWithAccessKey:dhKey withSecretKey: dhSec];
    
    NSArray *objects = [s3 listObjectsInBucket: bucket ];

    for( S3ObjectSummary *o in objects){
        
        path = [root stringByAppendingPathComponent: o.key ];
        
        
        pathExists = [fileManager fileExistsAtPath: path isDirectory: &isDir ];

        // Object is a folder...
        if ( [o.key hasSuffix: @"/" ]  ){

            if( pathExists && !isDir ){
                // This folder exists as a file, it should be deleted...
                
            }
            else if( !pathExists ){
                // The folder doesn't exist so should be created...
                [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error ];
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

                request = [[S3GetObjectRequest alloc ] initWithKey: o.key withBucket: bucket ];
                [requestQueue addObject: request];
                request.delegate = self;
                NSLog(@"%@", o.key);
            
            }
            else if( !( [[ self objectS3eTag: o ] isEqualToString:[ downloadHelper fileMD5: path ] ] ) ){
                // File exists but the MD5 has changed on the bucket, need to update...

                request = [[S3GetObjectRequest alloc ] initWithKey: o.key withBucket: bucket ];
                [requestQueue addObject: request];
                request.delegate = self;
                NSLog(@"needs update");
            }
        }

    }
    
   // S3GetObjectResponse *r = [ s3 getObject: g ];

    

}


-(void) downloadKey:(NSString*)key{
    AmazonS3Client *s3 = [[AmazonS3Client alloc] initWithAccessKey:dhKey withSecretKey: dhSec];
    S3GetObjectRequest *gor = [[S3GetObjectRequest alloc ] initWithKey: key withBucket: bucket ];
    gor.delegate = self;
    self.data=[[NSMutableData alloc] init ];
    [s3Client getObject:gor];
}

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
