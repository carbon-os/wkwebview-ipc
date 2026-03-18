# wkwebview-ipc

Binary IPC for WKWebView. Send and receive raw `ArrayBuffer`s between JavaScript
and native Objective-C/C++ over named channels.

Works around WKWebView's lack of native ArrayBuffer support over `WKScriptMessageHandler`
by routing binary data through `WKURLSchemeHandler` instead. Zero dependencies,
no JSON serialization, no base64 — just raw bytes over named channels.

Requires macOS 13.0+ / iOS 16.0+

---

## API

### JavaScript / TypeScript

```ts
import ipc from 'wkwebview-ipc'

// Native → JS
ipc.on("data.out", (buffer: ArrayBuffer) => {
    const bytes = new Uint8Array(buffer)
    // interpret as whatever you need — text, binary, frames, samples
})

// JS → Native
ipc.send("data.in", buffer)
```

### Objective-C

```objc
#import <wkwebview-ipc/IPC.h>

// Native → JS
[IPC send:@"data.out" data:data];

// JS → Native
[IPC on:@"data.in" handler:^(NSData *data) {
    // raw bytes — interpret however you like
}];
```

### C++ (optional)

```cpp
#include <wkwebview-ipc/ipc_cpp.h>

// Native → JS
ipc::send("data.out", ptr, len);

// JS → Native
ipc::on("data.in", [](const void* ptr, size_t len) {
    // raw bytes — interpret however you like
});
```

---

## Setup

### 1. Native

Register the scheme and attach before loading any content:

```objc
WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
[cfg setURLSchemeHandler:[[IPCSchemeHandler alloc] init] forURLScheme:@"ipc"];

self.webView = [[WKWebView alloc] initWithFrame:rect configuration:cfg];
[IPC attachToWebView:self.webView];

[self.webView loadRequest:[NSURLRequest requestWithURL:
    [NSURL URLWithString:@"ipc://app/"]]];
```

### 2. JavaScript

```bash
npm install wkwebview-ipc
```

Or copy `js/dist/ipc.js` directly into your app bundle resources.

```html
<script type="module">
    import ipc from './ipc.js'

    ipc.on("data.out", buf => {
        // raw ArrayBuffer — yours to decode
    })
</script>
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

## How it works

```
JS ipc.send("data.in", buffer)
  → fetch POST ipc://app/ipc/send/data.in   (ArrayBuffer body)
  → WKURLSchemeHandler resolves body
  → NSNotification → [IPC on:] handler
  → your native code

ipc::send("data.out", ptr, len)
  → IPCSchemeHandler pushChannel
  → didReceiveData on open XHR stream
  → ipc.on("data.out") callback             (ArrayBuffer)
  → your JS code
```

No main thread blocking. No JSON. No base64.
The XHR stream stays open for the lifetime of the page —
native can push bytes at any time.

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
  js/
    src/
      ipc.ts
    dist/
      ipc.js         — compiled (gitignored)
      ipc.d.ts       — type declarations
    package.json
    tsconfig.json
  CMakeLists.txt
  README.md
  BUILD.md
```

---

## License

MIT