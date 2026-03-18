#import <wkwebview-ipc/IPC.h>
#import "IPCSchemeHandler.h"

static IPCSchemeHandler *gHandler = nil;

@implementation IPC

+ (id<WKURLSchemeHandler>)schemeHandler {
    if (!gHandler)
        gHandler = [[IPCSchemeHandler alloc] init];
    return gHandler;
}

+ (void)attachToWebView:(WKWebView *)webView {
    // Ensure handler exists if caller skipped schemeHandler call
    if (!gHandler)
        gHandler = [[IPCSchemeHandler alloc] init];

    WKUserScript *script = [[WKUserScript alloc]
        initWithSource:[IPC ipcScript]
        injectionTime:WKUserScriptInjectionTimeAtDocumentStart
        forMainFrameOnly:YES];
    [webView.configuration.userContentController addUserScript:script];

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

+ (NSString *)ipcScript {
    return
        @"(function() {"
         "  const _handlers = {};"
         "  const _scheme   = 'ipc';"

         "  function _openStream(channel) {"
         "    const xhr = new XMLHttpRequest();"
         "    xhr.open('GET', _scheme + '://app/ipc/stream/' + channel, true);"
         "    xhr.overrideMimeType('text/plain; charset=x-user-defined');"
         "    let pos = 0;"
         "    xhr.onprogress = () => {"
         "      const chunk = xhr.responseText.slice(pos);"
         "      pos = xhr.responseText.length;"
         "      const buf = new Uint8Array(chunk.length);"
         "      for (let i = 0; i < chunk.length; i++)"
         "        buf[i] = chunk.charCodeAt(i) & 0xff;"
         "      (_handlers[channel] || []).forEach(cb => cb(buf.buffer));"
         "    };"
         "    xhr.onerror   = () => setTimeout(() => _openStream(channel), 500);"
         "    xhr.onloadend = () => setTimeout(() => _openStream(channel), 500);"
         "    xhr.send();"
         "  }"

         "  window.ipc = {"
         "    send(channel, buffer) {"
         "      fetch(_scheme + '://app/ipc/send/' + channel, {"
         "        method: 'POST',"
         "        body: buffer instanceof ArrayBuffer ? buffer : new Uint8Array(buffer)"
         "      }).catch(e => console.error('[ipc] send error', e));"
         "    },"
         "    on(channel, callback) {"
         "      if (!_handlers[channel]) {"
         "        _handlers[channel] = [];"
         "        _openStream(channel);"
         "      }"
         "      _handlers[channel].push(callback);"
         "    }"
         "  };"
         "})();";
}

@end