// Adapted from HermesEnabler/Gester (MIT). See bundled license notices.
#import "WatchRespring.h"
#import <CoreGraphics/CoreGraphics.h>
#import <objc/message.h>
#import <dlfcn.h>

static id gRespringWebView;
static id gRespringOverlay;

static id bq_send_id(id object, const char *name) {
    return ((id (*)(id, SEL))objc_msgSend)(object, sel_registerName(name));
}

static id bq_key_window(void) {
    Class applicationClass = NSClassFromString(@"UIApplication");
    id application = bq_send_id(applicationClass, "sharedApplication");
    if (!application) return nil;
    id scenes = bq_send_id(application, "connectedScenes");
    for (id scene in scenes) {
        if (![scene respondsToSelector:sel_registerName("windows")]) continue;
        for (id window in bq_send_id(scene, "windows")) {
            if (((BOOL (*)(id, SEL))objc_msgSend)(window, sel_registerName("isKeyWindow"))) return window;
        }
    }
    if ([application respondsToSelector:sel_registerName("windows")]) {
        return [bq_send_id(application, "windows") firstObject];
    }
    return nil;
}


BOOL GestaltWatchStartRespring(NSError **error) {
    void *webKit = dlopen("/System/Library/Frameworks/WebKit.framework/WebKit", RTLD_NOW | RTLD_LOCAL);
    Class configurationClass = NSClassFromString(@"WKWebViewConfiguration");
    Class webViewClass = NSClassFromString(@"WKWebView");
    Class viewClass = NSClassFromString(@"UIView");
    Class colorClass = NSClassFromString(@"UIColor");
    id window = bq_key_window();
    NSURL *url = [NSBundle.mainBundle URLForResource:@"respring" withExtension:@"html"];
    if (!webKit || !window || !url || !configurationClass || !webViewClass || !viewClass || !colorClass) {
        if (error) *error = [NSError errorWithDomain:@"GestaltEdit.WatchRespring" code:1
            userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Watch interface restart is unavailable. Restart Apple Watch manually.", nil)}];
        return NO;
    }
    CGRect bounds = ((CGRect (*)(id, SEL))objc_msgSend)(window, sel_registerName("bounds"));
    id config = bq_send_id(configurationClass, "new");
    id preferences = bq_send_id(config, "defaultWebpagePreferences");
    ((void (*)(id, SEL, BOOL))objc_msgSend)(preferences, sel_registerName("setAllowsContentJavaScript:"), YES);
    id webView = ((id (*)(id, SEL, CGRect, id))objc_msgSend)(bq_send_id(webViewClass, "alloc"), sel_registerName("initWithFrame:configuration:"), bounds, config);
    id overlay = ((id (*)(id, SEL, CGRect))objc_msgSend)(bq_send_id(viewClass, "alloc"), sel_registerName("initWithFrame:"), bounds);
    if (!webView || !overlay) {
        if (error) *error = [NSError errorWithDomain:@"GestaltEdit.WatchRespring" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Could not prepare Watch interface restart."}];
        return NO;
    }
    ((void (*)(id, SEL, id))objc_msgSend)(overlay, sel_registerName("setBackgroundColor:"), bq_send_id(colorClass, "blackColor"));
    ((void (*)(id, SEL, NSUInteger))objc_msgSend)(webView, sel_registerName("setAutoresizingMask:"), 18);
    ((void (*)(id, SEL, NSUInteger))objc_msgSend)(overlay, sel_registerName("setAutoresizingMask:"), 18);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(webView, sel_registerName("setUserInteractionEnabled:"), NO);
    // Delay execution so the iPhone can receive the acceptance reply first.
    gRespringWebView = webView;
    gRespringOverlay = overlay;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        ((void (*)(id, SEL, id))objc_msgSend)(window, sel_registerName("addSubview:"), webView);
        ((void (*)(id, SEL, id))objc_msgSend)(window, sel_registerName("addSubview:"), overlay);
        ((id (*)(id, SEL, id, id))objc_msgSend)(webView, sel_registerName("loadFileURL:allowingReadAccessToURL:"), url, url.URLByDeletingLastPathComponent);
        // If NeoSpring does not restart Carousel, restore the helper UI.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            ((void (*)(id, SEL))objc_msgSend)(webView, sel_registerName("removeFromSuperview"));
            ((void (*)(id, SEL))objc_msgSend)(overlay, sel_registerName("removeFromSuperview"));
            gRespringWebView = nil;
            gRespringOverlay = nil;
        });
    });
    return YES;
}
