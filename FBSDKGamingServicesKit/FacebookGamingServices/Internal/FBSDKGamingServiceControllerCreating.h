/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import <FacebookGamingServices/FBSDKGamingServiceCompletionHandler.h>

#import "FBSDKGamingServiceControllerProtocol.h"
#import "FBSDKGamingServiceType.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(GamingServiceControllerCreating)
@protocol FBSDKGamingServiceControllerCreating

- (id<FBSDKGamingServiceController>)createWithServiceType:(FBSDKGamingServiceType)serviceType
                                               completion:(FBSDKGamingServiceResultCompletion)completion
                                            pendingResult:(nullable id)pendingResult;

@end

NS_ASSUME_NONNULL_END
