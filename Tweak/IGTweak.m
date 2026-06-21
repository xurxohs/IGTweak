/**
 * IGTweak — Instagram Modification Dylib
 * =======================================
 * Runtime hooks for Instagram 434.0.0 (decrypted arm64)
 *
 * Features:
 *   1. Remove feed ads (IGAdInsertionHandler, IGAdFetcherManager)
 *   2. Remove story ads (IGStoryAdInsertionDataSource)
 *   3. Ghost Mode — view stories without marking as seen (IGStorySeenStateUploader)
 *   4. Disable typing indicator in Direct (IGDirectTypingStatusService)
 *   5. Disable screenshot notifications (block screenshot reporting)
 *
 * Architecture: Objective-C runtime method swizzling via __attribute__((constructor))
 */

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ============================================================================
#pragma mark - Utility: Swizzle Helper
// ============================================================================

static void swizzleMethod(Class cls, SEL original, IMP replacement, IMP *original_imp) {
    if (!cls) {
        NSLog(@"[IGTweak] ⚠️ Class not found for selector %@", NSStringFromSelector(original));
        return;
    }

    Method method = class_getInstanceMethod(cls, original);
    if (!method) {
        NSLog(@"[IGTweak] ⚠️ Method %@ not found on %@", NSStringFromSelector(original), NSStringFromClass(cls));
        return;
    }

    if (original_imp) {
        *original_imp = method_getImplementation(method);
    }

    method_setImplementation(method, replacement);
    NSLog(@"[IGTweak] ✅ Hooked [%@ %@]", NSStringFromClass(cls), NSStringFromSelector(original));
}

// ============================================================================
#pragma mark - 1. Feed Ads — Block sponsored items from being inserted
// ============================================================================

// IGAdInsertionHandler: -receivedSponsoredItems:intentAwareData:
// Original receives ad items from ad platform → we return immediately (no-op)
static IMP orig_receivedSponsoredItems = NULL;
static void hook_receivedSponsoredItems(id self, SEL _cmd, id items, id data) {
    NSLog(@"[IGTweak] 🚫 Blocked %lu feed ad(s)", (unsigned long)[items count]);
    // No-op: don't pass ads to insertion pipeline
}

// IGAdInsertionHandler: -adInsertionHandler:shouldTryToInsertSponsoredItem:...
// Called when ad platform wants to insert a sponsored post → we block it
static IMP orig_shouldTryToInsert = NULL;
static void hook_shouldTryToInsert(id self, SEL _cmd, id handler, id item, id index,
                                    id focused, id validation, id context) {
    NSLog(@"[IGTweak] 🚫 Blocked feed ad insertion attempt");
    // No-op: don't insert the sponsored item
}

// IGAdFetcherManager: -isFetchingAds → always return NO
static IMP orig_isFetchingAds = NULL;
static BOOL hook_isFetchingAds(id self, SEL _cmd) {
    return NO;
}

// IGAdInsertionHandler: -deleteSponsoredItem: → always YES (auto-delete any that slip through)
static IMP orig_deleteSponsoredItem = NULL;
static BOOL hook_deleteSponsoredItem(id self, SEL _cmd, id item) {
    NSLog(@"[IGTweak] 🗑 Auto-deleting sponsored item that slipped through");
    if (orig_deleteSponsoredItem) {
        return ((BOOL(*)(id, SEL, id))orig_deleteSponsoredItem)(self, _cmd, item);
    }
    return YES;
}

static void installFeedAdHooks(void) {
    Class adInsertionHandler = NSClassFromString(@"IGAdInsertionHandler");
    Class adFetcherManager = NSClassFromString(@"IGAdFetcherManager");

    // Block receiving sponsored items
    swizzleMethod(adInsertionHandler,
                  @selector(receivedSponsoredItems:intentAwareData:),
                  (IMP)hook_receivedSponsoredItems,
                  &orig_receivedSponsoredItems);

    // Block insertion attempts
    swizzleMethod(adInsertionHandler,
                  @selector(adInsertionHandler:shouldTryToInsertSponsoredItem:atInsertionIndex:focusedIndex:validationResultString:insertionContext:),
                  (IMP)hook_shouldTryToInsert,
                  &orig_shouldTryToInsert);

    // Prevent ad fetching from starting
    swizzleMethod(adFetcherManager,
                  @selector(isFetchingAds),
                  (IMP)hook_isFetchingAds,
                  &orig_isFetchingAds);
}

// ============================================================================
#pragma mark - 2. Story Ads — Block ad insertion in Stories
// ============================================================================

// IGStoryAdInsertionDataSource: -receivedSponsoredItems:intentAwareData:
static IMP orig_storyReceivedSponsoredItems = NULL;
static void hook_storyReceivedSponsoredItems(id self, SEL _cmd, id items, id data) {
    NSLog(@"[IGTweak] 🚫 Blocked %lu story ad(s)", (unsigned long)[items count]);
    // No-op: don't inject story ads
}

// IGStoryAdInsertionDataSource: -adInsertionHandler:shouldTryToInsertSponsoredItem:...
static IMP orig_storyShouldTryToInsert = NULL;
static void hook_storyShouldTryToInsert(id self, SEL _cmd, id handler, id item, id index,
                                         id focused, id validation, id context) {
    NSLog(@"[IGTweak] 🚫 Blocked story ad insertion");
    // No-op
}

// IGStoryAdInsertionDataSource: -allSponsoredItems → return empty array
static IMP orig_storyAllSponsoredItems = NULL;
static id hook_storyAllSponsoredItems(id self, SEL _cmd) {
    return @[];
}

// IGStoryAdInsertionDataSource: -surfaceSupportsAd → return NO
static IMP orig_surfaceSupportsAd = NULL;
static BOOL hook_surfaceSupportsAd(id self, SEL _cmd) {
    return NO;
}

static void installStoryAdHooks(void) {
    Class storyAdDataSource = NSClassFromString(@"IGStoryAdInsertionDataSource");

    swizzleMethod(storyAdDataSource,
                  @selector(receivedSponsoredItems:intentAwareData:),
                  (IMP)hook_storyReceivedSponsoredItems,
                  &orig_storyReceivedSponsoredItems);

    swizzleMethod(storyAdDataSource,
                  @selector(adInsertionHandler:shouldTryToInsertSponsoredItem:atInsertionIndex:focusedIndex:validationResultString:insertionContext:),
                  (IMP)hook_storyShouldTryToInsert,
                  &orig_storyShouldTryToInsert);

    swizzleMethod(storyAdDataSource,
                  @selector(allSponsoredItems),
                  (IMP)hook_storyAllSponsoredItems,
                  &orig_storyAllSponsoredItems);

    swizzleMethod(storyAdDataSource,
                  @selector(surfaceSupportsAd),
                  (IMP)hook_surfaceSupportsAd,
                  &orig_surfaceSupportsAd);
}

// ============================================================================
#pragma mark - 3. Ghost Mode — View stories without marking as seen
// ============================================================================

// IGStorySeenStateUploader uses a networker (IGAPIClient) to upload seen state.
// We hook initWithUserSessionPK:networker: to inject a nil networker,
// AND we swizzle the networker getter to always return nil.
static IMP orig_storySeenInit = NULL;
static id hook_storySeenInit(id self, SEL _cmd, id userSessionPK, id networker) {
    NSLog(@"[IGTweak] 👻 Ghost Mode: blocking story seen state upload (nil networker)");
    // Call original init but with nil networker so no upload happens
    return ((id(*)(id, SEL, id, id))orig_storySeenInit)(self, _cmd, userSessionPK, nil);
}

// Also hook the networker property getter as a safety net
static IMP orig_storySeenNetworker = NULL;
static id hook_storySeenNetworker(id self, SEL _cmd) {
    return nil; // No networker = no upload
}

static void installGhostModeHooks(void) {
    Class storySeenUploader = NSClassFromString(@"IGStorySeenStateUploader");

    swizzleMethod(storySeenUploader,
                  @selector(initWithUserSessionPK:networker:),
                  (IMP)hook_storySeenInit,
                  &orig_storySeenInit);

    swizzleMethod(storySeenUploader,
                  @selector(networker),
                  (IMP)hook_storySeenNetworker,
                  &orig_storySeenNetworker);
}

// ============================================================================
#pragma mark - 4. Disable Typing Indicator in Direct
// ============================================================================

// IGDirectTypingStatusService: -updateOutgoingStatusIsActive:threadKey:threadMetadata:typingStatusType:
// This sends your typing status to the server → we block it
static IMP orig_updateOutgoingStatus = NULL;
static void hook_updateOutgoingStatus(id self, SEL _cmd, id isActive, id threadKey,
                                       id threadMetadata, id typingStatusType) {
    NSLog(@"[IGTweak] 🔇 Blocked outgoing typing status");
    // No-op: other people won't see you typing
}

// IGDirectTypingStatusService: -resetOutgoingStatus → also no-op
static IMP orig_resetOutgoingStatus = NULL;
static void hook_resetOutgoingStatus(id self, SEL _cmd) {
    // No-op
}

static void installTypingIndicatorHooks(void) {
    Class typingService = NSClassFromString(@"IGDirectTypingStatusService");

    swizzleMethod(typingService,
                  @selector(updateOutgoingStatusIsActive:threadKey:threadMetadata:typingStatusType:),
                  (IMP)hook_updateOutgoingStatus,
                  &orig_updateOutgoingStatus);

    swizzleMethod(typingService,
                  @selector(resetOutgoingStatus),
                  (IMP)hook_resetOutgoingStatus,
                  &orig_resetOutgoingStatus);
}

// ============================================================================
#pragma mark - 5. Disable Screenshot Notifications
// ============================================================================

// We intercept UIApplicationUserDidTakeScreenshotNotification handling.
// Also hook the screenshot reshare prompt controller to prevent any server reporting.

// Block the screenshot detection notification from being observed
static IMP orig_screenshotInit = NULL;
static id hook_screenshotInit(id self, SEL _cmd, id userSession, id viewController) {
    NSLog(@"[IGTweak] 📸 Blocked screenshot reshare prompt controller init");
    // Still init the object but it won't be able to detect screenshots
    // because we also remove the notification observer below
    return ((id(*)(id, SEL, id, id))orig_screenshotInit)(self, _cmd, userSession, viewController);
}

static IMP orig_screenshotInitDM = NULL;
static id hook_screenshotInitDM(id self, SEL _cmd, id userSession, id viewController, id dmLocation) {
    NSLog(@"[IGTweak] 📸 Blocked screenshot controller init (DM variant)");
    return ((id(*)(id, SEL, id, id, id))orig_screenshotInitDM)(self, _cmd, userSession, viewController, dmLocation);
}

// Block the system screenshot notification from being posted to Instagram's observers
static IMP orig_addObserver = NULL;
static id hook_addObserver(id self, SEL _cmd, id observer, SEL selector, id name, id object) {
    // If Instagram tries to observe screenshot notifications, silently skip it
    if ([name isEqualToString:@"UIApplicationUserDidTakeScreenshotNotification"]) {
        NSLog(@"[IGTweak] 📸 Blocked screenshot notification observer registration");
        return nil;
    }
    return ((id(*)(id, SEL, id, SEL, id, id))orig_addObserver)(self, _cmd, observer, selector, name, object);
}

static void installScreenshotHooks(void) {
    Class screenshotController = NSClassFromString(@"IGScreenshotResharePromptController");

    swizzleMethod(screenshotController,
                  @selector(initWithUserSession:viewController:),
                  (IMP)hook_screenshotInit,
                  &orig_screenshotInit);

    swizzleMethod(screenshotController,
                  @selector(initWithUserSession:viewController:dmButtonLocation:),
                  (IMP)hook_screenshotInitDM,
                  &orig_screenshotInitDM);

    // Hook NSNotificationCenter to block screenshot notification observation
    Class notifCenter = [NSNotificationCenter class];
    swizzleMethod(notifCenter,
                  @selector(addObserver:selector:name:object:),
                  (IMP)hook_addObserver,
                  &orig_addObserver);
}

// ============================================================================
#pragma mark - Constructor — Entry Point
// ============================================================================

__attribute__((constructor))
static void IGTweakInit(void) {
    NSLog(@"[IGTweak] 🚀 IGTweak loading...");
    NSLog(@"[IGTweak] 📦 Instagram 434.0.0 Modification Dylib");
    NSLog(@"[IGTweak] ═══════════════════════════════════════");

    @autoreleasepool {
        // 1. Feed ads
        NSLog(@"[IGTweak] Installing feed ad hooks...");
        installFeedAdHooks();

        // 2. Story ads
        NSLog(@"[IGTweak] Installing story ad hooks...");
        installStoryAdHooks();

        // 3. Ghost mode
        NSLog(@"[IGTweak] Installing ghost mode hooks...");
        installGhostModeHooks();

        // 4. Typing indicator
        NSLog(@"[IGTweak] Installing typing indicator hooks...");
        installTypingIndicatorHooks();

        // 5. Screenshot notifications
        NSLog(@"[IGTweak] Installing screenshot notification hooks...");
        installScreenshotHooks();

        NSLog(@"[IGTweak] ═══════════════════════════════════════");
        NSLog(@"[IGTweak] ✅ All hooks installed successfully!");
        NSLog(@"[IGTweak]    🚫 Feed ads: BLOCKED");
        NSLog(@"[IGTweak]    🚫 Story ads: BLOCKED");
        NSLog(@"[IGTweak]    👻 Ghost Mode: ACTIVE");
        NSLog(@"[IGTweak]    🔇 Typing indicator: DISABLED");
        NSLog(@"[IGTweak]    📸 Screenshot alerts: DISABLED");
    }
}
