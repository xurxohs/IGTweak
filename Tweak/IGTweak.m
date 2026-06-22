#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ============================================================================
#pragma mark - Preferences / NSUserDefaults Keys
// ============================================================================

#define kIGTweakBlockAds @"IGTweak_BlockAds"
#define kIGTweakGhostMode @"IGTweak_GhostMode"
#define kIGTweakBlockTyping @"IGTweak_BlockTyping"
#define kIGTweakBlockAnalytics @"IGTweak_BlockAnalytics"

static BOOL tweakEnabled(NSString *key) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:key] == nil) {
        return YES; // Default state is ON
    }
    return [defaults boolForKey:key];
}

// ============================================================================
#pragma mark - Tweak Settings UI
// ============================================================================

@interface IGTweakSettingsViewController : UITableViewController
@end

@implementation IGTweakSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Настройки IGTweak";
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"Закрыть" style:UIBarButtonItemStyleDone target:self action:@selector(closeTapped)];
    self.navigationItem.rightBarButtonItem = closeButton;
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 4;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"TweakCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        UISwitch *toggle = [[UISwitch alloc] init];
        [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    }
    
    UISwitch *toggle = (UISwitch *)cell.accessoryView;
    toggle.tag = indexPath.row;
    
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"Блокировка рекламы";
            cell.detailTextLabel.text = @"Отключить рекламу в Ленте и Историях";
            toggle.on = tweakEnabled(kIGTweakBlockAds);
            break;
        case 1:
            cell.textLabel.text = @"Режим Невидимки";
            cell.detailTextLabel.text = @"Просмотр историй без отметки \"просмотрено\"";
            toggle.on = tweakEnabled(kIGTweakGhostMode);
            break;
        case 2:
            cell.textLabel.text = @"Скрыть набор текста";
            cell.detailTextLabel.text = @"Скрыть статус \"печатает...\" в Директе";
            toggle.on = tweakEnabled(kIGTweakBlockTyping);
            break;
        case 3:
            cell.textLabel.text = @"Блокировка слежки";
            cell.detailTextLabel.text = @"Отключить сбор аналитики Facebook";
            toggle.on = tweakEnabled(kIGTweakBlockAnalytics);
            break;
    }
    
    return cell;
}

- (void)switchChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    switch (sender.tag) {
        case 0: [defaults setBool:sender.isOn forKey:kIGTweakBlockAds]; break;
        case 1: [defaults setBool:sender.isOn forKey:kIGTweakGhostMode]; break;
        case 2: [defaults setBool:sender.isOn forKey:kIGTweakBlockTyping]; break;
        case 3: [defaults setBool:sender.isOn forKey:kIGTweakBlockAnalytics]; break;
    }
    [defaults synchronize];
}
@end

@interface IGTweakGestureHandler : NSObject
+ (instancetype)sharedInstance;
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender;
@end

@implementation IGTweakGestureHandler
+ (instancetype)sharedInstance {
    static IGTweakGestureHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topController.presentedViewController) {
            topController = topController.presentedViewController;
        }
        
        IGTweakSettingsViewController *settingsVC = [[IGTweakSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
        
        [topController presentViewController:nav animated:YES completion:nil];
    }
}
@end


// ============================================================================
#pragma mark - Utility: Swizzle Helper
// ============================================================================

static void swizzleMethod(Class cls, SEL original, IMP replacement, IMP *original_imp) {
    if (!cls) return;
    Method method = class_getInstanceMethod(cls, original);
    if (!method) return;
    if (original_imp) *original_imp = method_getImplementation(method);
    method_setImplementation(method, replacement);
    NSLog(@"[IGTweak] ✅ Hooked [%@ %@]", NSStringFromClass(cls), NSStringFromSelector(original));
}

// ============================================================================
#pragma mark - 1. Feed Ads — Block sponsored items from being inserted
// ============================================================================

static IMP orig_receivedSponsoredItems = NULL;
static void hook_receivedSponsoredItems(id self, SEL _cmd, id items, id data) {
    if (tweakEnabled(kIGTweakBlockAds)) {
        return; // Block
    }
    if (orig_receivedSponsoredItems) {
        ((void(*)(id, SEL, id, id))orig_receivedSponsoredItems)(self, _cmd, items, data);
    }
}

static IMP orig_shouldTryToInsert = NULL;
static void hook_shouldTryToInsert(id self, SEL _cmd, id handler, id item, id index, id focused, id validation, id context) {
    if (tweakEnabled(kIGTweakBlockAds)) {
        return; // Block
    }
    if (orig_shouldTryToInsert) {
        ((void(*)(id, SEL, id, id, id, id, id, id))orig_shouldTryToInsert)(self, _cmd, handler, item, index, focused, validation, context);
    }
}

static IMP orig_isFetchingAds = NULL;
static BOOL hook_isFetchingAds(id self, SEL _cmd) {
    if (tweakEnabled(kIGTweakBlockAds)) {
        return NO;
    }
    if (orig_isFetchingAds) {
        return ((BOOL(*)(id, SEL))orig_isFetchingAds)(self, _cmd);
    }
    return NO;
}

static IMP orig_deleteSponsoredItem = NULL;
static BOOL hook_deleteSponsoredItem(id self, SEL _cmd, id item) {
    if (orig_deleteSponsoredItem) {
        return ((BOOL(*)(id, SEL, id))orig_deleteSponsoredItem)(self, _cmd, item);
    }
    return YES;
}

static void installFeedAdHooks(void) {
    Class adInsertionHandler = NSClassFromString(@"IGAdInsertionHandler");
    Class adFetcherManager = NSClassFromString(@"IGAdFetcherManager");

    swizzleMethod(adInsertionHandler, @selector(receivedSponsoredItems:intentAwareData:), (IMP)hook_receivedSponsoredItems, &orig_receivedSponsoredItems);
    swizzleMethod(adInsertionHandler, @selector(adInsertionHandler:shouldTryToInsertSponsoredItem:atInsertionIndex:focusedIndex:validationResultString:insertionContext:), (IMP)hook_shouldTryToInsert, &orig_shouldTryToInsert);
    swizzleMethod(adFetcherManager, @selector(isFetchingAds), (IMP)hook_isFetchingAds, &orig_isFetchingAds);
}

// ============================================================================
#pragma mark - 2. Story Ads — Block ad insertion in Stories
// ============================================================================

static IMP orig_storyReceivedSponsoredItems = NULL;
static void hook_storyReceivedSponsoredItems(id self, SEL _cmd, id items, id data) {
    if (tweakEnabled(kIGTweakBlockAds)) {
        return; // Block
    }
    if (orig_storyReceivedSponsoredItems) {
        ((void(*)(id, SEL, id, id))orig_storyReceivedSponsoredItems)(self, _cmd, items, data);
    }
}

static IMP orig_storyShouldTryToInsert = NULL;
static void hook_storyShouldTryToInsert(id self, SEL _cmd, id handler, id item, id index, id focused, id validation, id context) {
    if (tweakEnabled(kIGTweakBlockAds)) {
        return; // Block
    }
    if (orig_storyShouldTryToInsert) {
        ((void(*)(id, SEL, id, id, id, id, id, id))orig_storyShouldTryToInsert)(self, _cmd, handler, item, index, focused, validation, context);
    }
}

static IMP orig_storyAllSponsoredItems = NULL;
static id hook_storyAllSponsoredItems(id self, SEL _cmd) {
    if (tweakEnabled(kIGTweakBlockAds)) {
        return @[];
    }
    if (orig_storyAllSponsoredItems) {
        return ((id(*)(id, SEL))orig_storyAllSponsoredItems)(self, _cmd);
    }
    return @[];
}

static IMP orig_surfaceSupportsAd = NULL;
static BOOL hook_surfaceSupportsAd(id self, SEL _cmd) {
    if (tweakEnabled(kIGTweakBlockAds)) {
        return NO;
    }
    if (orig_surfaceSupportsAd) {
        return ((BOOL(*)(id, SEL))orig_surfaceSupportsAd)(self, _cmd);
    }
    return YES;
}

static void installStoryAdHooks(void) {
    Class storyAdDataSource = NSClassFromString(@"IGStoryAdInsertionDataSource");

    swizzleMethod(storyAdDataSource, @selector(receivedSponsoredItems:intentAwareData:), (IMP)hook_storyReceivedSponsoredItems, &orig_storyReceivedSponsoredItems);
    swizzleMethod(storyAdDataSource, @selector(adInsertionHandler:shouldTryToInsertSponsoredItem:atInsertionIndex:focusedIndex:validationResultString:insertionContext:), (IMP)hook_storyShouldTryToInsert, &orig_storyShouldTryToInsert);
    swizzleMethod(storyAdDataSource, @selector(allSponsoredItems), (IMP)hook_storyAllSponsoredItems, &orig_storyAllSponsoredItems);
    swizzleMethod(storyAdDataSource, @selector(surfaceSupportsAd), (IMP)hook_surfaceSupportsAd, &orig_surfaceSupportsAd);
}

// ============================================================================
#pragma mark - 3. Ghost Mode — View stories without marking as seen
// ============================================================================

static IMP orig_storySeenInit = NULL;
static id hook_storySeenInit(id self, SEL _cmd, id userSessionPK, id networker) {
    if (tweakEnabled(kIGTweakGhostMode)) {
        return ((id(*)(id, SEL, id, id))orig_storySeenInit)(self, _cmd, userSessionPK, nil);
    }
    return ((id(*)(id, SEL, id, id))orig_storySeenInit)(self, _cmd, userSessionPK, networker);
}

static IMP orig_storySeenNetworker = NULL;
static id hook_storySeenNetworker(id self, SEL _cmd) {
    if (tweakEnabled(kIGTweakGhostMode)) {
        return nil;
    }
    if (orig_storySeenNetworker) {
        return ((id(*)(id, SEL))orig_storySeenNetworker)(self, _cmd);
    }
    return nil;
}

static void installGhostModeHooks(void) {
    Class storySeenUploader = NSClassFromString(@"IGStorySeenStateUploader");

    swizzleMethod(storySeenUploader, @selector(initWithUserSessionPK:networker:), (IMP)hook_storySeenInit, &orig_storySeenInit);
    swizzleMethod(storySeenUploader, @selector(networker), (IMP)hook_storySeenNetworker, &orig_storySeenNetworker);
}

// ============================================================================
#pragma mark - 4. Disable Typing Indicator in Direct
// ============================================================================

static IMP orig_updateOutgoingStatus = NULL;
static void hook_updateOutgoingStatus(id self, SEL _cmd, id isActive, id threadKey, id threadMetadata, id typingStatusType) {
    if (tweakEnabled(kIGTweakBlockTyping)) {
        return; // Block
    }
    if (orig_updateOutgoingStatus) {
        ((void(*)(id, SEL, id, id, id, id))orig_updateOutgoingStatus)(self, _cmd, isActive, threadKey, threadMetadata, typingStatusType);
    }
}

static IMP orig_resetOutgoingStatus = NULL;
static void hook_resetOutgoingStatus(id self, SEL _cmd) {
    if (tweakEnabled(kIGTweakBlockTyping)) {
        return;
    }
    if (orig_resetOutgoingStatus) {
        ((void(*)(id, SEL))orig_resetOutgoingStatus)(self, _cmd);
    }
}

static void installTypingIndicatorHooks(void) {
    Class typingService = NSClassFromString(@"IGDirectTypingStatusService");

    swizzleMethod(typingService, @selector(updateOutgoingStatusIsActive:threadKey:threadMetadata:typingStatusType:), (IMP)hook_updateOutgoingStatus, &orig_updateOutgoingStatus);
    swizzleMethod(typingService, @selector(resetOutgoingStatus), (IMP)hook_resetOutgoingStatus, &orig_resetOutgoingStatus);
}

// ============================================================================
#pragma mark - 5. Disable Screenshot Notifications
// ============================================================================

static IMP orig_screenshotInit = NULL;
static id hook_screenshotInit(id self, SEL _cmd, id userSession, id viewController) {
    return ((id(*)(id, SEL, id, id))orig_screenshotInit)(self, _cmd, userSession, viewController);
}

static IMP orig_screenshotInitDM = NULL;
static id hook_screenshotInitDM(id self, SEL _cmd, id userSession, id viewController, id dmLocation) {
    return ((id(*)(id, SEL, id, id, id))orig_screenshotInitDM)(self, _cmd, userSession, viewController, dmLocation);
}

static IMP orig_addObserver = NULL;
static id hook_addObserver(id self, SEL _cmd, id observer, SEL selector, id name, id object) {
    if (tweakEnabled(kIGTweakBlockAnalytics) && [name isEqualToString:@"UIApplicationUserDidTakeScreenshotNotification"]) {
        return nil;
    }
    return ((id(*)(id, SEL, id, SEL, id, id))orig_addObserver)(self, _cmd, observer, selector, name, object);
}

static void installScreenshotHooks(void) {
    Class screenshotController = NSClassFromString(@"IGScreenshotResharePromptController");
    swizzleMethod(screenshotController, @selector(initWithUserSession:viewController:), (IMP)hook_screenshotInit, &orig_screenshotInit);
    swizzleMethod(screenshotController, @selector(initWithUserSession:viewController:dmButtonLocation:), (IMP)hook_screenshotInitDM, &orig_screenshotInitDM);
    swizzleMethod([NSNotificationCenter class], @selector(addObserver:selector:name:object:), (IMP)hook_addObserver, &orig_addObserver);
}

// ============================================================================
#pragma mark - 6. Analytics and Ad Tracking Telemetry
// ============================================================================

id (*orig_FBAdTrackingDataReporter_init)(id, SEL, id, id, id, id);
static id new_FBAdTrackingDataReporter_init(id self, SEL _cmd, id store, id logger, id helper, id config) {
    if (tweakEnabled(kIGTweakBlockAnalytics)) {
        return nil;
    }
    return orig_FBAdTrackingDataReporter_init(self, _cmd, store, logger, helper, config);
}

static IMP orig_FBAnalyticsBladeRunner_writeEventToStream = NULL;
static void new_FBAnalyticsBladeRunner_writeEventToStream(id self, SEL _cmd, id event) {
    if (tweakEnabled(kIGTweakBlockAnalytics)) {
        return;
    }
    if (orig_FBAnalyticsBladeRunner_writeEventToStream) {
        ((void(*)(id, SEL, id))orig_FBAnalyticsBladeRunner_writeEventToStream)(self, _cmd, event);
    }
}

static void installTrackingHooks(void) {
    Class adTrackingClass = NSClassFromString(@"FBAdTrackingDataReporter");
    Class fbAnalyticsStreamClass = NSClassFromString(@"FBAnalyticsBladeRunnerRequestStreamProvider");

    if (adTrackingClass) {
        swizzleMethod(adTrackingClass, @selector(initWithPreferencesDataStore:logger:helper:config:), (IMP)new_FBAdTrackingDataReporter_init, (IMP *)&orig_FBAdTrackingDataReporter_init);
    }
    if (fbAnalyticsStreamClass) {
        swizzleMethod(fbAnalyticsStreamClass, @selector(writeEventToStream:), (IMP)new_FBAnalyticsBladeRunner_writeEventToStream, &orig_FBAnalyticsBladeRunner_writeEventToStream);
    }
}

// ============================================================================
#pragma mark - 7. UIWindow Gesture Injection
// ============================================================================

static IMP orig_makeKeyAndVisible = NULL;
static void hook_makeKeyAndVisible(UIWindow *self, SEL _cmd) {
    if (orig_makeKeyAndVisible) {
        ((void(*)(id, SEL))orig_makeKeyAndVisible)(self, _cmd);
    }
    
    BOOL hasGesture = NO;
    for (UIGestureRecognizer *g in self.gestureRecognizers) {
        if ([g.name isEqualToString:@"IGTweakGesture"]) {
            hasGesture = YES;
            break;
        }
    }
    
    if (!hasGesture) {
        UILongPressGestureRecognizer *recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:[IGTweakGestureHandler sharedInstance] action:@selector(handleLongPress:)];
        recognizer.numberOfTouchesRequired = 3;
        recognizer.minimumPressDuration = 1.0;
        recognizer.name = @"IGTweakGesture";
        [self addGestureRecognizer:recognizer];
        NSLog(@"[IGTweak] 👆 Added 3-finger long press gesture to window");
    }
}

static void installWindowHooks(void) {
    swizzleMethod([UIWindow class], @selector(makeKeyAndVisible), (IMP)hook_makeKeyAndVisible, &orig_makeKeyAndVisible);
}

// ============================================================================
#pragma mark - Constructor — Entry Point
// ============================================================================

__attribute__((constructor))
static void IGTweakInit(void) {
    NSLog(@"[IGTweak] 🚀 IGTweak loading with UI...");
    @autoreleasepool {
        installFeedAdHooks();
        installStoryAdHooks();
        installGhostModeHooks();
        installTypingIndicatorHooks();
        installScreenshotHooks();
        installTrackingHooks();
        installWindowHooks();
        NSLog(@"[IGTweak] ✅ All hooks and UI installed successfully!");
    }
}
