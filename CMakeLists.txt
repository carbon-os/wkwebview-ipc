cmake_minimum_required(VERSION 3.20)
project(wkwebview-ipc LANGUAGES C OBJC OBJCXX)

set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0")
set(CMAKE_OBJC_FLAGS   "${CMAKE_OBJC_FLAGS}   -fobjc-arc")
set(CMAKE_OBJCXX_FLAGS "${CMAKE_OBJCXX_FLAGS} -fobjc-arc")

find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)
find_library(WEBKIT_FRAMEWORK     WebKit     REQUIRED)

add_library(wkwebview-ipc STATIC
    src/IPC.m
    src/IPCSchemeHandler.m
)

set_source_files_properties(
    src/IPC.m
    src/IPCSchemeHandler.m
    PROPERTIES LANGUAGE OBJC COMPILE_FLAGS "-fobjc-arc"
)

target_include_directories(wkwebview-ipc
    PUBLIC  ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(wkwebview-ipc
    ${FOUNDATION_FRAMEWORK}
    ${WEBKIT_FRAMEWORK}
)