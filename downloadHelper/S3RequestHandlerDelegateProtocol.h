//
//  S3RequestHandlerDelegateProtocol.h
//  downloadHelper
//
//  Created by Jonathan Dring on 25/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import <Foundation/Foundation.h>


@class S3RequestHandler;

@protocol S3RequestHandlerDelegateProtocol <NSObject>


@required

- (void)downloadComplete:( S3RequestHandler * )request;
- (void)downloadFailedWithError:(NSError*)error;
- (void)downloadFailedWithException:(NSException*)exception;

@end
