/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

@import TestTools;

#import "FBSDKAppEvents.h"
#import "FBSDKAppEventsState+Testing.h"
#import "FBSDKAppEventsStateFactory.h"
#import "FBSDKApplicationObserving.h"
#import "FBSDKAuthenticationToken+Internal.h"
#import "FBSDKCodelessIndexer+Testing.h"
#import "FBSDKConversionValueUpdating.h"
#import "FBSDKCoreKitTests-Swift.h"
#import "FBSDKCrashShield+Internal.h"
#import "FBSDKCrashShield+Testing.h"
#import "FBSDKEventDeactivationManager.h"
#import "FBSDKFeatureExtractor.h"
#import "FBSDKFeatureExtractor+Testing.h"
#import "FBSDKFeatureManager.h"
#import "FBSDKGraphRequestConnection+Testing.h"
#import "FBSDKPaymentObserver.h"
#import "FBSDKProfile+Testing.h"
#import "FBSDKRestrictiveDataFilterManager.h"
#import "FBSDKRestrictiveDataFilterManager+Testing.h"
#import "FBSDKSKAdNetworkReporter+Testing.h"
#import "FBSDKTimeSpentData.h"

@interface FBSDKApplicationDelegateTests : XCTestCase

@property (nonatomic) FBSDKApplicationDelegate *delegate;
@property (nonatomic) TestFeatureManager *featureChecker;
@property (nonatomic) TestAppEvents *appEvents;
@property (nonatomic) UserDefaultsSpy *store;
@property (nonatomic) TestSettings *settings;
@property (nonatomic) TestBackgroundEventLogger *backgroundEventLogger;

@end

@implementation FBSDKApplicationDelegateTests

static NSString *bitmaskKey = @"com.facebook.sdk.kits.bitmask";

- (void)setUp
{
  [super setUp];

  [self.class resetTestData];

  self.appEvents = [TestAppEvents new];
  self.settings = [TestSettings new];
  self.featureChecker = [TestFeatureManager new];
  self.backgroundEventLogger = [[TestBackgroundEventLogger alloc] initWithInfoDictionaryProvider:[TestBundle new]
                                                                                     eventLogger:self.appEvents];
  TestServerConfigurationProvider *serverConfigurationProvider = [[TestServerConfigurationProvider alloc]
                                                                  initWithConfiguration:ServerConfigurationFixtures.defaultConfig];
  self.delegate = [[FBSDKApplicationDelegate alloc] initWithNotificationCenter:[TestNotificationCenter new]
                                                                   tokenWallet:TestAccessTokenWallet.class
                                                                      settings:self.settings
                                                                featureChecker:self.featureChecker
                                                                     appEvents:self.appEvents
                                                   serverConfigurationProvider:serverConfigurationProvider
                                                                         store:self.store
                                                     authenticationTokenWallet:TestAuthenticationTokenWallet.class
                                                               profileProvider:TestProfileProvider.class
                                                         backgroundEventLogger:self.backgroundEventLogger
                                                               paymentObserver:[TestPaymentObserver new]];
  self.delegate.isAppLaunched = NO;

  [self.delegate resetApplicationObserverCache];
}

- (void)tearDown
{
  [super tearDown];

  self.delegate = nil;

  [self.class resetTestData];
  [self.settings reset];
}

+ (void)resetTestData
{
  [TestAccessTokenWallet reset];
  [TestAuthenticationTokenWallet reset];
  [TestGateKeeperManager reset];
  [TestProfileProvider reset];
}

// MARK: - Lifecycle Methods

- (void)testInitializingSdkEnablesGraphRequests
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [FBSDKGraphRequestConnection resetCanMakeRequests];

  [self.delegate initializeSDKWithLaunchOptions:@{}];

  XCTAssertTrue(
    [FBSDKGraphRequestConnection canMakeRequests],
    "Initializing the SDK should enable making graph requests"
  );
}

- (void)testInitializingSdkConfiguresEventsProcessorsForAppEventsState
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [FBSDKAppEvents reset];

  [self.delegate initializeSDKWithLaunchOptions:@{}];

  NSArray *expected = @[
    self.appEvents.capturedConfigureEventDeactivationParameterProcessor,
    self.appEvents.capturedConfigureRestrictiveDataFilterParameterProcessor
  ];
  XCTAssertEqualObjects(
    FBSDKAppEventsState.eventProcessors,
    expected,
    "Initializing the SDK should configure events processors for FBSDKAppEventsState"
  );
}

- (void)testInitializingSdkConfiguresGateKeeperManager
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [FBSDKGateKeeperManager reset];

  [self.delegate initializeSDKWithLaunchOptions:@{}];

  NSObject *graphRequestFactory = (NSObject *)FBSDKGateKeeperManager.graphRequestFactory;
  NSObject *graphRequestConnectionFactory = (NSObject *)FBSDKGateKeeperManager.graphRequestConnectionFactory;
  NSObject *store = (NSObject *)FBSDKGateKeeperManager.store;

  XCTAssertTrue(
    [FBSDKGateKeeperManager canLoadGateKeepers],
    "Initializing the SDK should enable loading gatekeepers"
  );

  XCTAssertEqualObjects(
    graphRequestFactory.class,
    FBSDKGraphRequestFactory.class,
    "Should be configured with the expected concrete graph request provider"
  );
  XCTAssertEqualObjects(
    graphRequestConnectionFactory.class,
    FBSDKGraphRequestConnectionFactory.class,
    "Should be configured with the expected concrete graph request connection provider"
  );
  XCTAssertEqualObjects(
    store,
    NSUserDefaults.standardUserDefaults,
    "Should be configured with the expected concrete data store"
  );
}

- (void)testConfiguringCodelessIndexer
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];
  NSObject *graphRequestFactory = (NSObject *)[FBSDKCodelessIndexer graphRequestFactory];
  NSObject *serverConfigurationProvider = (NSObject *)[FBSDKCodelessIndexer serverConfigurationProvider];
  NSObject *store = (NSObject *)[FBSDKCodelessIndexer store];
  NSObject *graphRequestConnectionFactory = (NSObject *)[FBSDKCodelessIndexer graphRequestConnectionFactory];
  NSObject *swizzler = (NSObject *)[FBSDKCodelessIndexer swizzler];
  NSObject *settings = (NSObject *)[FBSDKCodelessIndexer settings];
  NSObject *advertiserIDProvider = (NSObject *)[FBSDKCodelessIndexer advertiserIDProvider];
  XCTAssertEqualObjects(
    graphRequestFactory.class,
    FBSDKGraphRequestFactory.class,
    "Should be configured with the expected concrete graph request provider"
  );
  XCTAssertEqualObjects(
    serverConfigurationProvider,
    FBSDKServerConfigurationManager.shared,
    "Should be configured with the expected concrete server configuration provider"
  );
  XCTAssertEqualObjects(
    store,
    NSUserDefaults.standardUserDefaults,
    "Should be configured with the standard user defaults"
  );
  XCTAssertEqualObjects(
    graphRequestConnectionFactory.class,
    FBSDKGraphRequestConnectionFactory.class,
    "Should be configured with the expected concrete graph request connection provider"
  );
  XCTAssertEqualObjects(
    swizzler,
    FBSDKSwizzler.class,
    "Should be configured with the expected concrete swizzler"
  );
  XCTAssertEqualObjects(
    settings,
    FBSDKSettings.sharedSettings,
    "Should be configured with the expected concrete settings"
  );
  XCTAssertEqualObjects(
    advertiserIDProvider,
    FBSDKAppEventsUtility.shared,
    "Should be configured with the expected concrete advertiser identifier provider"
  );
}

- (void)testConfiguringCrashShield
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];
  NSObject *settings = (NSObject *)[FBSDKCrashShield settings];
  NSObject *graphRequestFactory = (NSObject *)[FBSDKCrashShield graphRequestFactory];
  NSObject *featureChecking = (NSObject *)[FBSDKCrashShield featureChecking];
  XCTAssertEqualObjects(
    settings.class,
    FBSDKSettings.class,
    "Should be configured with the expected settings"
  );
  XCTAssertEqualObjects(
    graphRequestFactory.class,
    FBSDKGraphRequestFactory.class,
    "Should be configured with the expected concrete graph request provider"
  );
  XCTAssertEqualObjects(
    featureChecking.class,
    FBSDKFeatureManager.class,
    "Should be configured with the expected concrete Feature manager"
  );
}

- (void)testConfiguringRestrictiveDataFilterManager
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];

  FBSDKRestrictiveDataFilterManager *restrictiveDataFilterManager = (FBSDKRestrictiveDataFilterManager *) self.appEvents.capturedConfigureRestrictiveDataFilterParameterProcessor;
  XCTAssertEqualObjects(
    restrictiveDataFilterManager.serverConfigurationProvider,
    FBSDKServerConfigurationManager.shared,
    "Should be configured with the expected concrete server configuration provider"
  );
}

- (void)testConfiguringFBSDKSKAdNetworkReporter
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];
  NSObject *graphRequestFactory = (NSObject *)[[self.delegate skAdNetworkReporter] graphRequestFactory];
  NSObject *store = (NSObject *)[[self.delegate skAdNetworkReporter] store];
  NSObject *conversionValueUpdatable = (NSObject *)[[self.delegate skAdNetworkReporter] conversionValueUpdatable];
  XCTAssertEqualObjects(
    graphRequestFactory.class,
    FBSDKGraphRequestFactory.class,
    "Should be configured with the expected concrete graph request provider"
  );
  XCTAssertEqualObjects(
    store,
    NSUserDefaults.standardUserDefaults,
    "Should be configured with the standard user defaults"
  );
  if (@available(iOS 11.3, *)) {
    XCTAssertEqualObjects(
      conversionValueUpdatable,
      SKAdNetwork.class,
      "Should be configured with the default Conversion Value Updating Class"
    );
  }
}

- (void)testInitializingSdkConfiguresAccessTokenCache
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  FBSDKAccessToken.tokenCache = nil;
  [self.delegate initializeSDKWithLaunchOptions:@{}];

  NSObject *tokenCache = (NSObject *) FBSDKAccessToken.tokenCache;
  XCTAssertEqualObjects(tokenCache.class, FBSDKTokenCache.class, "Should be configured with expected concrete token cache");
}

- (void)testInitializingSdkConfiguresProfile
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];
  NSObject *store = (NSObject *)[FBSDKProfile store];
  NSObject *tokenProvider = (NSObject *)[FBSDKProfile accessTokenProvider];
  NSObject *notificationCenter = (NSObject *)[FBSDKProfile notificationCenter];
  NSObject *settings = (NSObject *)[FBSDKProfile settings];
  NSObject *urlHoster = (NSObject *)[FBSDKProfile urlHoster];
  XCTAssertEqualObjects(
    store,
    NSUserDefaults.standardUserDefaults,
    "Should be configured with the expected concrete data store"
  );
  XCTAssertEqualObjects(
    tokenProvider,
    FBSDKAccessToken.class,
    "Should be configured with the expected concrete token provider"
  );
  XCTAssertEqualObjects(
    notificationCenter,
    NSNotificationCenter.defaultCenter,
    "Should be configured with the expected concrete Notification Center"
  );
  XCTAssertEqualObjects(
    settings,
    FBSDKSettings.sharedSettings,
    "Should be configured with the expected concrete Settings"
  );
  XCTAssertEqualObjects(
    urlHoster,
    FBSDKInternalUtility.sharedUtility,
    "Should be configured with the expected concrete Settings"
  );
}

- (void)testInitializingSdkConfiguresAuthenticationTokenCache
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];

  NSObject *tokenCache = (NSObject *) FBSDKAuthenticationToken.tokenCache;
  XCTAssertEqualObjects(tokenCache.class, FBSDKTokenCache.class, "Should be configured with expected concrete token cache");
}

- (void)testInitializingSdkConfiguresAccessTokenConnectionFactory
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  FBSDKAccessToken.graphRequestConnectionFactory = [TestGraphRequestConnectionFactory new];
  [self.delegate initializeSDKWithLaunchOptions:@{}];

  NSObject *graphRequestConnectionFactory = (NSObject *) FBSDKAccessToken.graphRequestConnectionFactory;
  XCTAssertEqualObjects(
    graphRequestConnectionFactory.class,
    FBSDKGraphRequestConnectionFactory.class,
    "Should be configured with expected concrete graph request connection factory"
  );
}

- (void)testInitializingSdkConfiguresSettings
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [FBSDKSettings.sharedSettings reset];
  [self.delegate initializeSDKWithLaunchOptions:@{}];

  NSObject *store = (NSObject *) FBSDKSettings.store;
  NSObject *appEventsConfigProvider = (NSObject *) FBSDKSettings.sharedSettings.appEventsConfigurationProvider;
  NSObject *infoDictionaryProvider = (NSObject *) FBSDKSettings.infoDictionaryProvider;
  NSObject *eventLogger = (NSObject *) FBSDKSettings.eventLogger;
  XCTAssertEqualObjects(
    store,
    NSUserDefaults.standardUserDefaults,
    "Should be configured with the expected concrete data store"
  );
  XCTAssertEqualObjects(
    appEventsConfigProvider,
    FBSDKAppEventsConfigurationManager.shared,
    "Should be configured with the expected concrete app events configuration provider"
  );
  XCTAssertEqualObjects(
    infoDictionaryProvider,
    NSBundle.mainBundle,
    "Should be configured with the expected concrete info dictionary provider"
  );
  XCTAssertEqualObjects(
    eventLogger,
    FBSDKAppEvents.shared,
    "Should be configured with the expected concrete event logger"
  );
}

- (void)testInitializingSdkConfiguresGraphRequestPiggybackManager
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];
  NSObject *tokenWallet = (NSObject *) FBSDKGraphRequestPiggybackManager.tokenWallet;
  NSObject *settings = (NSObject *) FBSDKGraphRequestPiggybackManager.settings;
  NSObject *serverConfiguration = (NSObject *) FBSDKGraphRequestPiggybackManager.serverConfiguration;
  NSObject *graphRequestFactory = (NSObject *) FBSDKGraphRequestPiggybackManager.graphRequestFactory;

  XCTAssertEqualObjects(
    tokenWallet,
    FBSDKAccessToken.class,
    "Should be configured with the expected concrete access token provider"
  );

  XCTAssertEqualObjects(
    settings,
    FBSDKSettings.sharedSettings,
    "Should be configured with the expected concrete settings"
  );
  XCTAssertEqualObjects(
    serverConfiguration,
    FBSDKServerConfigurationManager.shared,
    "Should be configured with the expected concrete server configuration"
  );

  XCTAssertEqualObjects(
    graphRequestFactory.class,
    FBSDKGraphRequestFactory.class,

    "Should be configured with the expected concrete graph request provider"
  );
}

- (void)testInitializingSdkAddsBridgeApiObserver
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];

  XCTAssertTrue(
    [self.delegate.applicationObservers containsObject:FBSDKBridgeAPI.sharedInstance],
    "Should add the shared bridge api instance to the application observers"
  );
}

- (void)testInitializingSdkPerformsSettingsLogging
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];
  XCTAssertEqual(
    self.settings.logWarningsCallCount,
    1,
    "Should have settings log warnings upon initialization"
  );
  XCTAssertEqual(
    self.settings.logIfSDKSettingsChangedCallCount,
    1,
    "Should have settings log if there were changes upon initialization"
  );
  XCTAssertEqual(
    self.settings.recordInstallCallCount,
    1,
    "Should have settings record installations upon initialization"
  );
}

- (void)testInitializingSdkPerformsBackgroundEventLogging
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];
  XCTAssertEqual(
    self.backgroundEventLogger.logBackgroundRefresStatusCallCount,
    1,
    "Should have background event logger log background refresh status upon initialization"
  );
}

// TEMP: added to configurator tests
- (void)testInitializingSdkConfiguresAppEventsConfigurationManager
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];
  NSObject *store = (NSObject *) FBSDKAppEventsConfigurationManager.shared.store;
  NSObject *settings = (NSObject *) FBSDKAppEventsConfigurationManager.shared.settings;
  NSObject *graphRequestFactory = (NSObject *) FBSDKAppEventsConfigurationManager.shared.graphRequestFactory;
  NSObject *graphRequestConnectionFactory = (NSObject *) FBSDKAppEventsConfigurationManager.shared.graphRequestConnectionFactory;

  XCTAssertEqualObjects(
    store,
    NSUserDefaults.standardUserDefaults,
    "Should be configured with the expected concrete data store"
  );
  XCTAssertEqualObjects(
    settings,
    FBSDKSettings.sharedSettings,
    "Should be configured with the expected concrete settings"
  );
  XCTAssertEqualObjects(
    graphRequestFactory.class,
    FBSDKGraphRequestFactory.class,
    "Should be configured with the expected concrete request provider"
  );
  XCTAssertEqualObjects(
    graphRequestConnectionFactory.class,
    FBSDKGraphRequestConnectionFactory.class,
    "Should be configured with the expected concrete connection provider"
  );
}

// TEMP: added to configurator tests as part of a complete test
- (void)testInitializingSdkConfiguresCurrentAccessTokenProviderForGraphRequest
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];

  XCTAssertEqualObjects(
    [FBSDKGraphRequest accessTokenProvider],
    FBSDKAccessToken.class,
    "Should be configered with expected access token class."
  );
}

// TEMP: added to configurator tests
- (void)testInitializingSdkConfiguresWebDialogView
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];
  NSObject *webViewProvider = (NSObject *) FBSDKWebDialogView.webViewProvider;
  NSObject *urlOpener = (NSObject *) FBSDKWebDialogView.urlOpener;
  XCTAssertEqualObjects(
    webViewProvider.class,
    FBSDKWebViewFactory.class,
    "Should be configured with the expected concrete web view provider"
  );
  XCTAssertEqualObjects(
    urlOpener,
    UIApplication.sharedApplication,
    "Should be configured with the expected concrete url opener"
  );
}

// TEMP: added to configurator tests
- (void)testInitializingSdkConfiguresFeatureExtractor
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];
  NSObject *keyProvider = (NSObject *) FBSDKFeatureExtractor.rulesFromKeyProvider;
  XCTAssertEqualObjects(
    keyProvider.class,
    FBSDKModelManager.class,
    "Should be configured with the expected concrete rules from key provider"
  );
}

- (void)testInitializingSdkChecksInstrumentFeature
{
  [FBSDKApplicationDelegate resetHasInitializeBeenCalled];
  [self.delegate initializeSDKWithLaunchOptions:@{}];
  XCTAssert(
    [self.featureChecker capturedFeaturesContains:FBSDKFeatureInstrument],
    "Should check if the instrument feature is enabled on initialization"
  );
}

- (void)testDidFinishLaunchingLaunchedApp
{
  self.delegate.isAppLaunched = YES;

  XCTAssertFalse(
    [self.delegate application:UIApplication.sharedApplication didFinishLaunchingWithOptions:nil],
    "Should return false if the application is already launched"
  );
}

- (void)testDidFinishLaunchingSetsCurrentAccessTokenWithCache
{
  FBSDKAccessToken *expected = SampleAccessTokens.validToken;
  TestTokenCache *cache = [[TestTokenCache alloc] initWithAccessToken:expected
                                                  authenticationToken:nil];
  TestAccessTokenWallet.tokenCache = cache;

  [self.delegate application:UIApplication.sharedApplication didFinishLaunchingWithOptions:nil];

  XCTAssertEqualObjects(
    TestAccessTokenWallet.currentAccessToken,
    expected,
    "Should set the current access token to the cached access token when it exists"
  );
}

- (void)testDidFinishLaunchingSetsCurrentAccessTokenWithoutCache
{
  TestAccessTokenWallet.currentAccessToken = SampleAccessTokens.validToken;
  [TestAccessTokenWallet setTokenCache:[[TestTokenCache alloc] initWithAccessToken:nil authenticationToken:nil]];

  [self.delegate application:UIApplication.sharedApplication didFinishLaunchingWithOptions:nil];

  XCTAssertNil(
    TestAccessTokenWallet.currentAccessToken,
    "Should set the current access token to nil access token when there isn't a cached token"
  );
}

- (void)testDidFinishLaunchingSetsCurrentAuthenticationTokenWithCache
{
  FBSDKAuthenticationToken *expected = SampleAuthenticationToken.validToken;
  TestTokenCache *cache = [[TestTokenCache alloc] initWithAccessToken:nil
                                                  authenticationToken:expected];
  TestAuthenticationTokenWallet.tokenCache = cache;
  [self.delegate application:UIApplication.sharedApplication didFinishLaunchingWithOptions:nil];

  XCTAssertEqualObjects(
    TestAuthenticationTokenWallet.currentAuthenticationToken,
    expected,
    "Should set the current authentication token to the cached access token when it exists"
  );
}

- (void)testDidFinishLaunchingSetsCurrentAuthenticationTokenWithoutCache
{
  TestTokenCache *cache = [[TestTokenCache alloc] initWithAccessToken:nil authenticationToken:nil];
  TestAuthenticationTokenWallet.tokenCache = cache;

  [self.delegate application:UIApplication.sharedApplication didFinishLaunchingWithOptions:nil];

  XCTAssertNil(
    TestAuthenticationTokenWallet.currentAuthenticationToken,
    "Should set the current authentication token to nil access token when there isn't a cached token"
  );
}

- (void)testDidFinishLaunchingWithAutoLogEnabled
{
  [self.settings setStubbedIsAutoLogAppEventsEnabled:YES];

  [self.store setInteger:1 forKey:bitmaskKey];

  [self.delegate application:UIApplication.sharedApplication didFinishLaunchingWithOptions:nil];

  XCTAssertEqualObjects(
    self.appEvents.capturedEventName,
    @"fb_sdk_initialize",
    "Should log initialization when auto log app events is enabled"
  );
}

- (void)testDidFinishLaunchingWithAutoLogDisabled
{
  [self.settings setStubbedIsAutoLogAppEventsEnabled:NO];

  [self.store setInteger:1 forKey:bitmaskKey];

  [self.delegate application:UIApplication.sharedApplication didFinishLaunchingWithOptions:nil];

  XCTAssertNil(
    self.appEvents.capturedEventName,
    "Should not log initialization when auto log app events are disabled"
  );
}

- (void)testDidFinishLaunchingWithObservers
{
  TestApplicationDelegateObserver *observer1 = [TestApplicationDelegateObserver new];
  TestApplicationDelegateObserver *observer2 = [TestApplicationDelegateObserver new];

  [self.delegate addObserver:observer1];
  [self.delegate addObserver:observer2];

  BOOL notifiedObservers = [self.delegate application:UIApplication.sharedApplication didFinishLaunchingWithOptions:nil];

  XCTAssertEqual(
    observer1.didFinishLaunchingCallCount,
    1,
    "Should invoke did finish launching on all observers"
  );
  XCTAssertEqual(
    observer2.didFinishLaunchingCallCount,
    1,
    "Should invoke did finish launching on all observers"
  );
  XCTAssertTrue(notifiedObservers, "Should indicate if observers were notified");
}

- (void)testDidFinishLaunchingWithoutObservers
{
  BOOL notifiedObservers = [self.delegate application:UIApplication.sharedApplication didFinishLaunchingWithOptions:nil];

  XCTAssertFalse(notifiedObservers, "Should indicate if no observers were notified");
}

- (void)testAppEventsEnabled
{
  [self.settings setStubbedIsAutoLogAppEventsEnabled:YES];

  NSNotification *notification = [[NSNotification alloc] initWithName:UIApplicationDidBecomeActiveNotification
                                                               object:self
                                                             userInfo:nil];

  [self.delegate applicationDidBecomeActive:notification];

  XCTAssertTrue(
    self.appEvents.wasActivateAppCalled,
    "Should have app events activate the app when autolog app events is enabled"
  );
  XCTAssertEqual(
    self.appEvents.capturedApplicationState,
    UIApplicationStateActive,
    "Should set the application state to active when the notification is received"
  );
}

- (void)testAppEventsDisabled
{
  [self.settings setStubbedIsAutoLogAppEventsEnabled:NO];

  NSNotification *notification = [[NSNotification alloc] initWithName:UIApplicationDidBecomeActiveNotification
                                                               object:self
                                                             userInfo:nil];
  [self.delegate applicationDidBecomeActive:notification];

  XCTAssertFalse(
    self.appEvents.wasActivateAppCalled,
    "Should not have app events activate the app when autolog app events is enabled"
  );
  XCTAssertEqual(
    self.appEvents.capturedApplicationState,
    UIApplicationStateActive,
    "Should set the application state to active when the notification is received"
  );
}

- (void)testSetApplicationState
{
  [self.delegate setApplicationState:UIApplicationStateBackground];
  XCTAssertEqual(
    self.appEvents.capturedApplicationState,
    UIApplicationStateBackground,
    "The value of applicationState after calling setApplicationState should be UIApplicationStateBackground"
  );
}

@end
