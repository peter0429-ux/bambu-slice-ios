# CMake 的 iOS 交叉编译工具链。
#
# 这个文件刻意写得很薄：CMake 自 iOS 3.14 起原生支持 CMAKE_SYSTEM_NAME=iOS，
# 大部分平台细节由 CMake 自己的 Platform/iOS-*.cmake 处理。
#
# 如果某个依赖（尤其是 Boost / TBB 这种带 try_compile 的）在这套工具链下
# 反复失败，换用社区维护更完整的版本会更省时间：
#     git clone https://github.com/leetal/ios-cmake
#     -DCMAKE_TOOLCHAIN_FILE=ios-cmake/ios.toolchain.cmake -DPLATFORM=OS64
#
# 用法：
#     cmake -B build-ios -G Xcode \
#           -DCMAKE_TOOLCHAIN_FILE=../scripts/ios.toolchain.cmake ..

set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_VERSION 16.0)

set(CMAKE_OSX_DEPLOYMENT_TARGET "16.0" CACHE STRING "iOS 最低版本")
set(CMAKE_OSX_SYSROOT "iphoneos" CACHE STRING "SDK")
set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "真机 arm64")

# 只读 SDK 里的头文件和库，别把宿主机 macOS 的东西混进来
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

# 静态链接，iOS 不允许随便加载动态库
set(BUILD_SHARED_LIBS OFF CACHE BOOL "iOS 只做静态库")

# 关掉对交叉编译不友好的探测
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
