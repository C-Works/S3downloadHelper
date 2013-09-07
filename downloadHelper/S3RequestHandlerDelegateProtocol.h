//
//  S3RequestHandlerDelegateProtocol.h
//  downloadHelper
//
//  Created by Jonathan Dring on 25/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import <Foundation/Foundation.h>



typedef enum{
    dhDOWNLOADING,
    dhSUSPENDED,
    dhCOMPLETE,
    dhINITIALISED
} SYNC_STATUS;


@class S3RequestHandler;
@class Reachability;

@protocol S3RequestHandlerDelegateProtocol <NSObject>



@optional

//- (void)progressChanged;


@required

- (BOOL)downloadEnable;

//- (NSString*)downloadedMD5:(S3RequestHandler*)S3RequestHandler;


- (NSString*)downloadPath:(S3RequestHandler*)S3RequestHandler;
- (NSString*)persistPath:(S3RequestHandler*)S3RequestHandler;


- (void)downloadFinished:( S3RequestHandler * )request;
- (void)downloadFailed:( S3RequestHandler * )request;

@property (atomic, readonly) SYNC_STATUS            status;


@end
