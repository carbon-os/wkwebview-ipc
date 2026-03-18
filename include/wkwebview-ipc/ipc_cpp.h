#pragma once
#import <wkwebview-ipc/IPC.h>
#include <functional>
#include <string>

namespace ipc {

inline void send(const std::string& channel, const void* ptr, size_t len) {
    [IPC send:@(channel.c_str())
         data:[NSData dataWithBytes:ptr length:len]];
}

inline void on(const std::string& channel, std::function<void(const void*, size_t)> handler) {
    [IPC on:@(channel.c_str()) handler:^(NSData *data) {
        handler(data.bytes, data.length);
    }];
}

} // namespace ipc