#import <wkwebview-ipc/IPC.h>
#import "IPCSchemeHandler.h"

static IPCSchemeHandler *gHandler = nil;

@implementation IPC

+ (void)attachToWebView:(WKWebView *)webView {
    gHandler = [[IPCSchemeHandler alloc] init];
    NSLog(@"[wkwebview-ipc] attached");
}

+ (void)send:(NSString *)channel data:(NSData *)data {
    if (!gHandler) {
        NSLog(@"[wkwebview-ipc] send called before attachToWebView");
        return;
    }
    [gHandler pushChannel:channel data:data];
}

+ (void)on:(NSString *)channel handler:(void(^)(NSData *))handler {
    NSString *notif = [@"ipc.in." stringByAppendingString:channel];
    [[NSNotificationCenter defaultCenter]
        addObserverForName:notif
        object:nil
        queue:nil
        usingBlock:^(NSNotification *note) {
            NSData *data = note.userInfo[@"data"];
            if (data) handler(data);
        }];
}

@end