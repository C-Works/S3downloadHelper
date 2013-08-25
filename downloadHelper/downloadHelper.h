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
#import <CommonCrypto/CommonDigest.h>
#import "Constants.h"


#define CHUNK_SIZE 100000


@interface downloadHelper : NSObject <AmazonServiceRequestDelegate>


-(void) updateApplicationFilesInBucket:(NSString*)bucket;



/** Static method to obtain the Registry singleton.
 */
+ (downloadHelper*)sharedInstance;

/** Overide method to ensure that a second singleton cannot be created, calling this will return the singleton object.
 */
+ (id)alloc;

/** Overide method to ensure that a second singleton cannot be created, calling this will return the singleton object.
 */
+ (id)allocWithZone:(NSZone *)zone;

/** Overide method to ensure that a second singleton cannot be created, calling this will return the singleton object.
 */
- (id)copyWithZone:(NSZone *)zone;

/** Overide method to ensure that a second singleton cannot be created, calling this will return the singleton object.
 */
- (id)retain;

/** Overide method to ensure that a second singleton cannot be created, calling this will return the singleton object.
 */
- (unsigned)retainCount;

/** Overide method to ensure that a second singleton cannot be created, calling this will return the singleton object.
 */
- (void)release;

/** Overide method to ensure that a second singleton cannot be created, calling this will return the singleton object.
 */
- (id)autorelease;



@end
