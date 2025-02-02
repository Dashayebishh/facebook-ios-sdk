/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import <FBSDKCoreKit/FBSDKButton.h>
#import <FBSDKCoreKit/FBSDKButtonImpressionTracking.h>

#import "FBSDKAccessTokenProtocols.h"
#import "FBSDKEventLogging.h"
#import "FBSDKIcon+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface FBSDKButton ()

@property (class, nullable, nonatomic, readonly) id applicationActivationNotifier;
@property (class, nullable, nonatomic, readonly) id<FBSDKEventLogging> eventLogger;
@property (class, nullable, nonatomic, readonly) Class<FBSDKAccessTokenProviding> accessTokenProvider;

#if FBTEST && DEBUG
+ (void)resetClassDependencies;
#endif

+ (void)configureWithApplicationActivationNotifier:(id)applicationActivationNotifier
                                       eventLogger:(id<FBSDKEventLogging>)eventLogger
                               accessTokenProvider:(Class<FBSDKAccessTokenProviding>)accessTokenProvider;

- (void)logTapEventWithEventName:(NSString *)eventName
                      parameters:(nullable NSDictionary<NSString *, id> *)parameters;
- (void)configureButton;
- (void) configureWithIcon:(FBSDKIcon *)icon
                     title:(NSString *)title
           backgroundColor:(UIColor *)backgroundColor
          highlightedColor:(UIColor *)highlightedColor
             selectedTitle:(NSString *)selectedTitle
              selectedIcon:(FBSDKIcon *)selectedIcon
             selectedColor:(UIColor *)selectedColor
  selectedHighlightedColor:(UIColor *)selectedHighlightedColor;
- (UIColor *)defaultBackgroundColor;
- (UIColor *)defaultDisabledColor;
- (UIFont *)defaultFont;
- (UIColor *)defaultHighlightedColor;
- (FBSDKIcon *)defaultIcon;
- (UIColor *)defaultSelectedColor;

@end

NS_ASSUME_NONNULL_END
