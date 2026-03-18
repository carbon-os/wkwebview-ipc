#pragma once
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface IPC : NSObject

// Step 1: get the handler and register it on the config BEFORE creating the webview
+ (id<WKURLSchemeHandler>)schemeHandler;

// Step 2: attach after webview is created (adds the injected script)
+ (void)attachToWebView:(WKWebView *)webView;

// Native → JS
+ (void)send:(NSString *)channel data:(NSData *)data;

// JS → Native
+ (void)on:(NSString *)channel handler:(void(^)(NSData *data))handler;

@end

NS_ASSUME_NONNULL_END