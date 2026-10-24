#
# 独立构建 libslic3r 到 iOS。
#
# 为什么不直接用 BambuStudio 的顶层 CMake：
#   他们的根 CMakeLists.txt 里 find_package(OpenSSL/CURL/OpenGL/GLEW/glfw3 REQUIRED)
#   不在 if(SLIC3R_GUI) 里，即使 -DSLIC3R_GUI=OFF 也会在 configure 阶段要求桌面 GL 生态。
#   GLEW / glfw3 在 iOS 上基本无解，所以必须自己写构建。
#
# 用法：
#   cmake -B build-core -DCMAKE_TOOLCHAIN_FILE=../scripts/ios.toolchain.cmake \
#         -DBAMBU_SRC=/path/to/BambuStudio
#   cmake --build build-core -j8
#
cmake_minimum_required(VERSION 3.20)
project(libslic3r_ios LANGUAGES C CXX)

set(BAMBU_SRC "" CACHE PATH "BambuStudio 源码根目录")
if(NOT BAMBU_SRC)
    message(FATAL_ERROR "必须传 -DBAMBU_SRC=<BambuStudio 源码根>")
endif()

set(DEPS "${CMAKE_CURRENT_LIST_DIR}/../Frameworks")

# 只编少量文件，用来快速验证 include 路径和宏对不对（约 1 分钟，而不是 10 分钟）
option(CORE_PROBE "只编探针文件" OFF)

# ── 版本头（他们的 CMake 会生成，我们照模板自己来）─────────────────
set(SLIC3R_APP_NAME        "BambuStudio")
set(SLIC3R_APP_KEY         "BambuStudio")
set(SLIC3R_VERSION         "01.09.00.00")
set(SLIC3R_BUILD_ID        "ios")
set(SLIC3R_BUILD_TIME      "unknown")
set(SLIC3R_COMPILE_VERSION "clang-ios")
set(BBL_RELEASE_TO_PUBLIC  1)
set(BBL_INTERNAL_TESTING   0)
configure_file("${CMAKE_CURRENT_LIST_DIR}/libslic3r_version.h.in"
               "${CMAKE_CURRENT_BINARY_DIR}/libslic3r_version.h" @ONLY)

# ── 源文件：从他们 CMakeLists 的 set(lisbslic3r_sources) 抽出后剪枝 ──
# sources.txt 是纯净清单（只有文件名，无注释）。这里再按扩展名过滤一次，
# 双保险：只要出现杂行（空格、#、中文说明），都不会被当成源文件。
# 这些文件依赖我们不打算移植的库（OpenCV / libnoise / libpng），
# 从源文件里剔除。静态库归档不解析符号，只要没人调用就不会有链接问题。
set(_excluded
    TexturePainting.cpp     # OpenCV
    FuzzySkin.cpp           # libnoise
    PNGReadWrite.cpp        # libpng（贴图读写）
    TextShape.cpp           # OCCT STEPCAFControl_Reader（文字浮雕，非必需）
    Arrange.cpp             # libnest2d 的 NLopt 优化器（多物件自动排布，单物件切片用不到）
)

file(STRINGS "${CMAKE_CURRENT_LIST_DIR}/sources.txt" _raw)
set(_srcs "")
foreach(f IN LISTS _raw)
    if("${f}" MATCHES "\\.(cpp|mm|c)$")
        get_filename_component(_bn "${f}" NAME)
        if(_bn IN_LIST _excluded)
            message(STATUS "  跳过 ${f}（依赖未移植的库）")
            continue()
        endif()
        list(APPEND _srcs "${BAMBU_SRC}/src/libslic3r/${f}")
    endif()
endforeach()
list(LENGTH _srcs _n)
message(STATUS "libslic3r 源文件: ${_n} 个")
if(_n EQUAL 0)
    message(FATAL_ERROR "sources.txt 没解析出任何源文件，检查格式")
endif()

# 提前把缺失的源文件挑出来并一次性报全，
# 否则 add_library 只会含糊地报 "Cannot find source file"。
set(_missing "")
foreach(s IN LISTS _srcs)
    if(NOT EXISTS "${s}")
        get_filename_component(_bn "${s}" NAME)
        list(APPEND _missing "${_bn}")
    endif()
endforeach()
if(_missing)
    list(LENGTH _missing _mn)
    message(FATAL_ERROR "[missing-sources] ${_mn} 个文件不存在: ${_missing}")
endif()

if(CORE_PROBE)
    # 挑几个有代表性的：boost 用得多、clipper 用得多、基础几何
    set(_probe
        Polygon.cpp
        ClipperUtils.cpp
        BoundingBox.cpp
        ExPolygon.cpp
        ExtrusionEntity.cpp
    )
    set(_srcs "")
    foreach(f IN LISTS _probe)
        list(APPEND _srcs "${BAMBU_SRC}/src/libslic3r/${f}")
    endforeach()
    message(STATUS "CORE_PROBE 模式，只编 ${_srcs}")
endif()

# ── 内联在 src/ 下的第三方（不用单独交叉编译）─────────────────────
file(GLOB _admesh  "${BAMBU_SRC}/src/admesh/*.c" "${BAMBU_SRC}/src/admesh/*.cpp")
file(GLOB _miniz   "${BAMBU_SRC}/src/miniz/*.c")
file(GLOB _minilzo "${BAMBU_SRC}/src/minilzo/*.c")
file(GLOB _qhull   "${BAMBU_SRC}/src/qhull/src/libqhull_r/*.c")
file(GLOB _nest2d  "${BAMBU_SRC}/src/libnest2d/*.cpp")
# clipper2 也是内联的，Clipper2Utils.cpp 需要它的实现
file(GLOB _clipper "${BAMBU_SRC}/src/clipper2/Clipper2Lib/src/*.cpp")
# libslic3r 里 Brim.cpp 等还引用老版 clipper（ClipperLib_Z），以及新版 qhull 的
# C++ 接口（orgQhull::Qhull）和 semver C 库。这些不编进去，链接时缺符号。
file(GLOB _qhullcpp   "${BAMBU_SRC}/src/qhull/src/libqhullcpp/*.cpp")
# qt-qhull.cpp 需要 Qt，去掉
list(REMOVE_ITEM _qhullcpp "${BAMBU_SRC}/src/qhull/src/libqhullcpp/qt-qhull.cpp")
file(GLOB _semver     "${BAMBU_SRC}/src/semver/semver.c")
file(GLOB _tess    "${BAMBU_SRC}/src/glu-libtess/*.c"
                   "${BAMBU_SRC}/src/glu-libtess/src/*.c")
if(CORE_PROBE)
    set(_admesh "")
    set(_miniz "")
    set(_minilzo "")
    set(_qhull "")
    set(_nest2d "")
    set(_clipper "")
    set(_qhullcpp "")
    set(_semver "")
    set(_tess "")
endif()

# 老版 clipper 的 Z 版。clipper_z.cpp 是 #define CLIPPERLIB_USE_XYZ + include "clipper.cpp"
# 的 hack；pchheader.hpp 里已 include 了无 Z 版 clipper.hpp，若给 clipper_z 也套
# -include pchheader，guard 被先占，ClipperLib_Z 就定义不出来。故单独编、不套 PCH。
add_library(clipper_z_obj OBJECT "${BAMBU_SRC}/src/clipper/clipper_z.cpp")
# src/clipper/clipper.cpp 是 libslic3r 魔改版：用 Eigen::Vector3d 做 Z 坐标、
# 用 libslic3r/Int128.hpp 做高精度乘加。所以这些头路径都得给。
target_include_directories(clipper_z_obj PRIVATE
    "${BAMBU_SRC}/src"
    "${BAMBU_SRC}/src/libslic3r"
    "${BAMBU_SRC}/src/clipper"
    "${BAMBU_SRC}/src/eigen"
    "${DEPS}/eigen/include"
    "${DEPS}/boost/include")

add_library(slic3r STATIC ${_srcs} ${_admesh} ${_miniz} ${_minilzo} ${_qhull} ${_nest2d} ${_clipper} ${_qhullcpp} ${_semver} ${_tess} $<TARGET_OBJECTS:clipper_z_obj>)

target_include_directories(slic3r PUBLIC
    # shim 必须排在最前面：用 CommonCrypto 顶掉 openssl/md5.h、openssl/sha.h，
    # 免得为了两个哈希函数去编一整库 OpenSSL
    "${CMAKE_CURRENT_LIST_DIR}/shim"
    "${BAMBU_SRC}/src"
    "${BAMBU_SRC}/src/libslic3r"
    "${BAMBU_SRC}/src/eigen"
    "${BAMBU_SRC}/src/libigl"
    "${BAMBU_SRC}/src/qhull/src"
    "${BAMBU_SRC}/src/admesh"
    "${BAMBU_SRC}/src/clipper2/Clipper2Lib/include"
    "${BAMBU_SRC}/src/clipper"
    "${BAMBU_SRC}/src/semver"
    "${BAMBU_SRC}/src/glu-libtess"
    "${BAMBU_SRC}/src/glu-libtess/include"
    "${BAMBU_SRC}/src/glu-libtess/src"
    "${BAMBU_SRC}/src/miniz"
    "${BAMBU_SRC}/src/libnest2d/include"
    "${BAMBU_SRC}/src/nlohmann"
    "${CMAKE_CURRENT_BINARY_DIR}"
    "${DEPS}/boost/include"
    "${DEPS}/tbb/include"
    "${DEPS}/cgal/include"
    "${DEPS}/eigen/include"
    "${DEPS}/zlib/include"
    "${DEPS}/png/include"
    "${DEPS}/expat/include"
    "${DEPS}/cereal/include"
)

target_compile_definitions(slic3r PUBLIC
    USE_TBB
    TBB_USE_CAPTURED_EXCEPTION=0
    SLIC3R_STATIC
    BOOST_ALLOW_DEPRECATED_HEADERS
    BOOST_BIND_GLOBAL_PLACEHOLDERS
)

target_compile_features(slic3r PUBLIC cxx_std_17)

# 他们的构建默认开 PCH（add_precompiled_header(libslic3r pchheader.hpp FORCEINCLUDE)），
# 每个 TU 都被强制 include 这个头。少了它，像 ClipperZUtils.hpp 这种
# 「依赖前序 include 才认识 ExPolygon」的文件会报 incomplete type。
#
# 注意：这里不用 target_precompile_headers —— CMake 生成 PCH 时用的是独立的
# 编译命令，在 iOS 交叉编译下拿不到 sysroot，会报 'cassert' file not found。
# 直接 -include 等价于 FORCEINCLUDE 的语义，只是没有预编译加速。
# glu-libtess 的 .c 文件在 iOS SDK 下缺 <limits.h>（LONG_MAX 未声明），
# 强制前置包含我们的兼容头。
set(_tess_shim "${CMAKE_CURRENT_LIST_DIR}/shim/tess_compat.h")
target_compile_options(slic3r PRIVATE
    "$<$<COMPILE_LANGUAGE:C>:-include${_tess_shim}>")

# 关键：必须限定 COMPILE_LANGUAGE:CXX。
# pchheader.hpp 里是 <cassert> 这类 C++ 头，套到 qhull/miniz 的 .c 文件上
# 会让 C 编译器找不到 cassert（上一轮 20 个文件全挂在这）。
target_compile_options(slic3r PRIVATE
    "$<$<COMPILE_LANGUAGE:CXX>:SHELL:-include ${BAMBU_SRC}/src/libslic3r/pchheader.hpp>")

# libslic3r 大量用异常和 dynamic_cast，这两个必须开
target_compile_options(slic3r PRIVATE
    -fexceptions
    -frtti
    # CommonCrypto 的 CC_MD5_* 在 iOS 13+ 标了 deprecated，只是警告，屏蔽掉
    -Wno-deprecated-declarations
    # Boost QVM 的老写法（template 关键字后面没跟模板参数）在 Clang 16+ 是错误，
    # 新版 Xcode 自带 Clang 26.x 会直接编不过，降级掉。
    -Wno-missing-template-arg-list-after-template-kw
)
