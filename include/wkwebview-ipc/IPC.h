#pragma once
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface IPC : NSObject

// Call once, before loadRequest
+ (void)attachToWebView:(WKWebView *)webView;

// Native → JS
+ (void)send:(NSString *)channel data:(NSData *)data;

// JS → Native
+ (void)on:(NSString *)channel handler:(void(^)(NSData *data))handler;

@end

NS_ASSUME_NONNULL_END