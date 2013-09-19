//
//  AppDelegate.h
//  downloadHelper
//
//  Created by Jonathan Dring on 24/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "S3SyncHelper.h"
#import "S3downloadHelperDelegateProtocol.h"


@interface AppDelegate : UIResponder <UIApplicationDelegate, S3downloadHelperDelegateProtocol>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic, strong) S3SyncHelper *d;
@property (nonatomic, strong) AmazonS3Client *s3;


@end
