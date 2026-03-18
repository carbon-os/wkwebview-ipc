# wkwebview-ipc

Binary IPC for WKWebView. Send and receive raw `ArrayBuffer`s between JavaScript
and native Objective-C/C++ over named channels. Zero dependencies, no JSON
serialization, no base64 — just raw bytes.

`window.ipc` is available automatically on every page — no JS files to bundle,
no imports, no setup on the web side.

Requires macOS 13.0+ / iOS 16.0+

---

## Setup

Register the scheme on `WKWebViewConfiguration` before the `WKWebView` is created,
then attach after:

```objc
#import <wkwebview-ipc/IPC.h>

WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
[cfg setURLSchemeHandler:[IPC schemeHandler] forURLScheme:@"ipc"];

WKWebView *webView = [[WKWebView alloc] initWithFrame:rect configuration:cfg];
[IPC attachToWebView:webView];

[IPC on:@"data.in" handler:^(NSData *data) {
    // raw bytes from JS
}];

[webView loadRequest:[NSURLRequest requestWithURL:
    [NSURL URLWithString:@"ipc://app/"]]];
```

```html
<script>
    ipc.on("data.out", buf => {
        const bytes = new Uint8Array(buf)
        // interpret however you need
    })

    ipc.send("data.in", buffer)  // ArrayBuffer
</script>
```

---

## API

### JavaScript

```js
// Receive from native
ipc.on("channel", (buffer) => {
    const bytes = new Uint8Array(buffer)
})

// Send to native
ipc.send("channel", buffer)  // ArrayBuffer
```

### Objective-C

```objc
// Send to JS
[IPC send:@"channel" data:data];

// Receive from JS
[IPC on:@"channel" handler:^(NSData *data) {
    // raw bytes
}];
```

### C++ (optional)

```cpp
#include <wkwebview-ipc/ipc_cpp.h>

// Send to JS
ipc::send("channel", ptr, len);

// Receive from JS
ipc::on("channel", [](const void* ptr, size_t len) {
    // raw bytes
});
```

---

## CMake

### FetchContent

```cmake
include(FetchContent)
FetchContent_Declare(
    wkwebview-ipc
    GIT_REPOSITORY https://github.com/yourname/wkwebview-ipc.git
    GIT_TAG        main
)
FetchContent_MakeAvailable(wkwebview-ipc)

target_link_libraries(YourApp wkwebview-ipc)
```

### Subdirectory

```cmake
add_subdirectory(wkwebview-ipc)
target_link_libraries(YourApp wkwebview-ipc)
```

---

## Repo structure

```
wkwebview-ipc/
  include/
    wkwebview-ipc/
      IPC.h          — Objective-C API
      ipc_cpp.h      — C++ sugar (optional)
  src/
    IPC.m
    IPCSchemeHandler.h
    IPCSchemeHandler.m
  CMakeLists.txt
  README.md
  BUILD.md
```

---

## How it works

Data flows through `WKURLSchemeHandler` rather than the standard WebKit JS bridge.
The standard bridge (`WKScriptMessageHandler` / `evaluateJavaScript`) requires all
calls to go through the main thread, blocks until WebKit processes each message,
and has no native ArrayBuffer support — binary data must be base64 encoded to cross it.

`WKURLSchemeHandler` has none of those constraints. Handlers fire on a background
GCD thread. The WebContent process where JS runs is a separate OS process with its
own thread budget — your app's main thread is only involved for the brief
`didReceiveData` call, nothing else.

```
native (GCD background)     main thread          WebContent process
───────────────────────     ───────────          ──────────────────
data arrives
  → IPC::send()
    → pushChannel()
      → dispatch_async ───→ didReceiveData()
                             (microseconds)
                                   │
                                   └──────────────→ XHR onprogress
                                                    ipc.on() callback
```

The VM, LLM inference loop, audio pipeline, or any other native workload runs
independently on its own threads and never competes with the UI or the JS runtime.

---

## License

MIT