#pragma once
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface IPCSchemeHandler : NSObject <WKURLSchemeHandler>

- (void)pushChannel:(NSString *)channel data:(NSData *)data;

@end

NS_ASSUME_NONNULL_END