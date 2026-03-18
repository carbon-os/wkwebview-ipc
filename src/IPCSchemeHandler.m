#import "IPCSchemeHandler.h"

@interface IPCSchemeHandler ()
@property (strong) NSMutableDictionary<NSString *, id<WKURLSchemeTask>> *streamTasks;
@property (strong) NSMutableDictionary<NSString *, NSMutableData *>     *pendingBuffers;
@end

@implementation IPCSchemeHandler

- (instancetype)init {
    if (self = [super init]) {
        _streamTasks    = [NSMutableDictionary dictionary];
        _pendingBuffers = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)pushChannel:(NSString *)channel data:(NSData *)data {
    dispatch_async(dispatch_get_main_queue(), ^{
        id<WKURLSchemeTask> task = self.streamTasks[channel];
        if (task) {
            [task didReceiveData:data];
        } else {
            if (!self.pendingBuffers[channel])
                self.pendingBuffers[channel] = [NSMutableData data];
            [self.pendingBuffers[channel] appendData:data];
        }
    });
}

- (void)webView:(WKWebView *)wv startURLSchemeTask:(id<WKURLSchemeTask>)task {
    NSString *path  = task.request.URL.path;
    NSArray  *parts = task.request.URL.pathComponents;

    // ── Static resources ──────────────────────────────────────────────
    if (![path hasPrefix:@"/ipc/"]) {
        NSString *file    = [path isEqualToString:@"/"] ? @"index.html" : [path lastPathComponent];
        NSString *resPath = [NSBundle.mainBundle.resourcePath
                             stringByAppendingPathComponent:file];

        NSLog(@"[ipc] static: %@", resPath);

        NSData *body = [NSData dataWithContentsOfFile:resPath];
        if (!body) {
            [task didReceiveResponse:[self responseForURL:task.request.URL
                                             contentType:@"text/plain"
                                              statusCode:404]];
            [task didReceiveData:[@"Not found" dataUsingEncoding:NSUTF8StringEncoding]];
            [task didFinish];
            return;
        }

        NSString *mime = @"text/plain";
        if ([file hasSuffix:@".html"]) mime = @"text/html; charset=utf-8";
        if ([file hasSuffix:@".js"])   mime = @"application/javascript";
        if ([file hasSuffix:@".css"])  mime = @"text/css";

        [task didReceiveResponse:[self responseForURL:task.request.URL
                                         contentType:mime
                                          statusCode:200]];
        [task didReceiveData:body];
        [task didFinish];
        return;
    }

    // ── IPC routes ────────────────────────────────────────────────────
    if (parts.count < 4) {
        [task didReceiveResponse:[self responseForURL:task.request.URL
                                         contentType:@"text/plain"
                                          statusCode:400]];
        [task didReceiveData:[@"bad request" dataUsingEncoding:NSUTF8StringEncoding]];
        [task didFinish];
        return;
    }

    NSString *verb    = parts[2]; // "send" or "stream"
    NSString *channel = parts[3];

    // ── JS → Native ───────────────────────────────────────────────────
    if ([verb isEqualToString:@"send"]) {
        NSData *body = [self resolveBody:task];
        if (body.length > 0)
            [[NSNotificationCenter defaultCenter]
                postNotificationName:[@"ipc.in." stringByAppendingString:channel]
                object:nil
                userInfo:@{@"data": body}];

        [task didReceiveResponse:[self responseForURL:task.request.URL
                                         contentType:@"text/plain"
                                          statusCode:200]];
        [task didReceiveData:[@"OK" dataUsingEncoding:NSUTF8StringEncoding]];
        [task didFinish];
    }

    // ── Native → JS ───────────────────────────────────────────────────
    else if ([verb isEqualToString:@"stream"]) {
        [task didReceiveResponse:[self responseForURL:task.request.URL
                                         contentType:@"application/octet-stream"
                                          statusCode:200]];
        self.streamTasks[channel] = task;

        NSMutableData *pending = self.pendingBuffers[channel];
        if (pending.length > 0) {
            [task didReceiveData:pending];
            [self.pendingBuffers removeObjectForKey:channel];
        }
    }

    // ── Unknown ───────────────────────────────────────────────────────
    else {
        [task didReceiveResponse:[self responseForURL:task.request.URL
                                         contentType:@"text/plain"
                                          statusCode:400]];
        [task didReceiveData:[@"unknown verb" dataUsingEncoding:NSUTF8StringEncoding]];
        [task didFinish];
    }
}

- (void)webView:(WKWebView *)wv stopURLSchemeTask:(id<WKURLSchemeTask>)task {
    NSString *key = [self.streamTasks allKeysForObject:task].firstObject;
    if (key) [self.streamTasks removeObjectForKey:key];
}

// ── Helpers ───────────────────────────────────────────────────────────

- (NSData *)resolveBody:(id<WKURLSchemeTask>)task {
    id body = task.request.HTTPBody;

    if ([body isKindOfClass:[NSData class]])
        return body;

    if ([body isKindOfClass:[NSArray class]]) {
        NSMutableData *md = [NSMutableData data];
        for (id part in (NSArray *)body)
            if ([part isKindOfClass:[NSData class]]) [md appendData:part];
        return md;
    }

    if (task.request.HTTPBodyStream) {
        NSInputStream *s = task.request.HTTPBodyStream;
        [s open];
        NSMutableData *md = [NSMutableData data];
        uint8_t buf[4096];
        while (s.hasBytesAvailable) {
            NSInteger n = [s read:buf maxLength:sizeof(buf)];
            if (n > 0) [md appendBytes:buf length:n]; else break;
        }
        [s close];
        return md;
    }

    return [NSData data];
}

- (NSHTTPURLResponse *)responseForURL:(NSURL *)url
                          contentType:(NSString *)contentType
                           statusCode:(NSInteger)statusCode {
    return [[NSHTTPURLResponse alloc]
        initWithURL:url
         statusCode:statusCode
        HTTPVersion:@"HTTP/1.1"
       headerFields:@{
           @"Content-Type":  contentType,
           @"Cache-Control": @"no-cache"
       }];
}

@end