//
//  S3downloadHelperDelegateProtocol.h
//  downloadHelper
//
//  Created by Jonathan Dring on 10/09/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol S3downloadHelperDelegateProtocol <NSObject>



@optional

// -------------------------------------------------------------------------------------------------
/** Method called on download delegate when the bucketlist is successfully updated by the download
 helper.
 */
- (void)bucketlistDidUpdate;
- (void)bucketListUpdateFailed:(id)s3sh;

- (void)transferDidComplete;
- (void)transferDidFail;




@end
