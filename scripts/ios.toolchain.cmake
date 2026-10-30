# CMake 的 iOS 交叉编译工具链。
#
# 这个文件刻意写得很薄：CMake 自 iOS 3.14 起原生支持 CMAKE_SYSTEM_NAME=iOS，
# 大部分平台细节由 CMake 自己的 Platform/iOS-*.cmake 处理。
#
# 用法：
#   真机（默认，用来出 ipa）：
#     cmake -B build-ios -DCMAKE_TOOLCHAIN_FILE=../scripts/ios.toolchain.cmake ..
#   模拟器（用来跑 XCTest）：
#     cmake -B build-ios-sim -DCMAKE_TOOLCHAIN_FILE=../scripts/ios.toolchain.cmake \
#           -DPLATFORM=simulator ..
#
# 为什么模拟器要单独编：模拟器目标是 arm64-apple-ios-simulator，
# 跟真机的 arm64-apple-ios 不是同一个 ABI，静态库不能混用。
# 依赖（boost/tbb/cgal…）和 libslic3r 都得各编一份。

set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_VERSION 16.0)

set(PLATFORM "device" CACHE STRING "device = 真机, simulator = 模拟器")
set(CMAKE_OSX_DEPLOYMENT_TARGET "16.0" CACHE STRING "iOS 最低版本")

if(PLATFORM STREQUAL "simulator")
    set(CMAKE_OSX_SYSROOT "iphonesimulator" CACHE STRING "SDK")
    if(NOT DEFINED CMAKE_OSX_ARCHITECTURES)
        # Apple Silicon 上的模拟器也是 arm64；Intel Mac 走 x86_64
        if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "arm64")
            set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "模拟器架构")
        else()
            set(CMAKE_OSX_ARCHITECTURES "x86_64" CACHE STRING "模拟器架构")
        endif()
    endif()
else()
    set(CMAKE_OSX_SYSROOT "iphoneos" CACHE STRING "SDK")
    if(NOT DEFINED CMAKE_OSX_ARCHITECTURES)
        set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "真机 arm64")
    endif()
endif()

message(STATUS "iOS 目标: ${PLATFORM} (${CMAKE_OSX_SYSROOT}, ${CMAKE_OSX_ARCHITECTURES})")

# 只读 SDK 里的头文件和库，别把宿主机 macOS 的东西混进来
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

# 静态链接，iOS 不允许随便加载动态库
set(BUILD_SHARED_LIBS OFF CACHE BOOL "iOS 只做静态库")

# 关掉对交叉编译不友好的探测
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
