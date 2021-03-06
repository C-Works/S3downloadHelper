//
//  AppDelegate.m
//  downloadHelper
//
//  Created by Jonathan Dring on 24/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import "AppDelegate.h"
#import "Constants.h"
#import <AWSS3/AmazonS3Client.h>
#import "S3SyncHelper.h"


@implementation AppDelegate
{
    S3SyncHelper *_d;
    AmazonS3Client *_s3;
}

@synthesize d  = _d;
@synthesize s3 = _s3;

// PROTOCOL Methods: S3DownloadHelper  
- (void)bucketlistDidUpdate{
    
    NSLog(@"Bucketlist did Update");
    
    [_d includeAll];
    [_d synchronise];
    
}

- (void)bucketListUpdateFailed:(id)s3sh{

    NSLog(@"Bucketlist update failed");

}



// PROTOCOL Methods: UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    _s3 = [[AmazonS3Client alloc] initWithAccessKey:dhKey withSecretKey: dhSec];
    _s3.endpoint = [AmazonEndpoints s3Endpoint: S3ENDPOINT ];
    _s3.timeout = 10000;
    
    _d = [[S3SyncHelper alloc ]initWithS3Client:_s3 forBucket: @"cncapplicationtest" delegate:self];
    //[_d resumeSynchronisation];
    
    [AmazonLogger turnLoggingOff];

    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    //[_d suspendSynchronisation];
    
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

    //[_d suspendSynchronisation];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.

    //[_d resumeSynchronisation];

}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    //[_d resumeSynchronisation];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.

}

@end
