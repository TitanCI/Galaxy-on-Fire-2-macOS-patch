// Shim for Galaxy on Fire 2: native fullscreen Space + keyboard focus in the fullscreen window.
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import <Security/Security.h>

static IMP origGoFullscreen;
static IMP origGoWindow;

static NSWindow *fsWindow(id controller) {
    Ivar iv = class_getInstanceVariable([controller class], "fullScreenWindow");
    return iv ? object_getIvar(controller, iv) : nil;
}

// The game's borderless window refuses key status, so every key press beeps.
static BOOL yes(id self, SEL _cmd) { return YES; }

// The game's empty windowed-mode window stays on screen next to the fullscreen one.
static void hideOtherWindows(NSWindow *keep) {
    for (NSWindow *o in [NSApp windows])
        if (o != keep && [o isVisible] && ![o isKindOfClass:[NSPanel class]]) [o orderOut:nil];
}

static void hookGoFullscreen(id self, SEL _cmd) {
    ((void (*)(id, SEL))origGoFullscreen)(self, _cmd);
    NSWindow *w = fsWindow(self);
    if (!w) return;
    [w setStyleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                    NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable |
                    NSWindowStyleMaskFullSizeContentView];
    [w setTitlebarAppearsTransparent:YES];
    [w setLevel:NSNormalWindowLevel];
    [w setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
    // The game only enables this on its windowed-mode window, so mouse steering needed a held button.
    [w setAcceptsMouseMovedEvents:YES];
    [w makeKeyAndOrderFront:nil];
    [w toggleFullScreen:nil];
    hideOtherWindows(w);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ hideOtherWindows(w); });
}

static void hookGoWindow(id self, SEL _cmd) {
    NSWindow *w = fsWindow(self);
    ((void (*)(id, SEL))origGoWindow)(self, _cmd);
    if (w) [w orderOut:nil];
}

__attribute__((constructor)) static void init(void) {
    Method m = class_getInstanceMethod([NSWindow class], @selector(canBecomeKeyWindow));
    method_setImplementation(m, (IMP)yes);
    m = class_getInstanceMethod([NSWindow class], @selector(canBecomeMainWindow));
    method_setImplementation(m, (IMP)yes);

    // Hook after the app has registered its classes.
    [[NSNotificationCenter defaultCenter]
        addObserverForName:NSApplicationDidFinishLaunchingNotification object:nil queue:nil
                usingBlock:^(NSNotification *n) {
        Class c = NSClassFromString(@"MainController");
        if (!c) return;
        Method a = class_getInstanceMethod(c, NSSelectorFromString(@"goFullscreenWindow"));
        Method b = class_getInstanceMethod(c, NSSelectorFromString(@"goWindow"));
        if (a) { origGoFullscreen = method_getImplementation(a); method_setImplementation(a, (IMP)hookGoFullscreen); }
        if (b) { origGoWindow = method_getImplementation(b); method_setImplementation(b, (IMP)hookGoWindow); }
    }];
}

// The game verifies its own Apple signature; the patched copy is ad-hoc signed.
static OSStatus fakeCheckValidity(SecStaticCodeRef code, SecCSFlags flags, SecRequirementRef req) { return errSecSuccess; }
__attribute__((used, section("__DATA,__interpose"))) static struct { const void *replacement, *original; }
    interposers[] = { { (const void *)fakeCheckValidity, (const void *)SecStaticCodeCheckValidity } };
