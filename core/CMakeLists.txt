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

# ── 源文件：从他们 CMakeLists 的 set(lisbslic3r_sources) 抽出来后剪枝 ──
file(STRINGS "${CMAKE_CURRENT_LIST_DIR}/sources.txt" _raw)
set(_srcs "")
foreach(f IN LISTS _raw)
    if(f STREQUAL "" OR f MATCHES "^#")
        continue()
    endif()
    list(APPEND _srcs "${BAMBU_SRC}/src/libslic3r/${f}")
endforeach()

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
if(CORE_PROBE)
    set(_admesh "")
    set(_miniz "")
    set(_minilzo "")
    set(_qhull "")
    set(_nest2d "")
endif()

add_library(slic3r STATIC ${_srcs} ${_admesh} ${_miniz} ${_minilzo} ${_qhull} ${_nest2d})

target_include_directories(slic3r PUBLIC
    "${BAMBU_SRC}/src"
    "${BAMBU_SRC}/src/libslic3r"
    "${BAMBU_SRC}/src/eigen"
    "${BAMBU_SRC}/src/libigl"
    "${BAMBU_SRC}/src/qhull/src"
    "${BAMBU_SRC}/src/admesh"
    "${BAMBU_SRC}/src/clipper2"
    "${BAMBU_SRC}/src/nlohmann"
    "${CMAKE_CURRENT_BINARY_DIR}"
    "${DEPS}/boost/include"
    "${DEPS}/tbb/include"
    "${DEPS}/cgal/include"
    "${DEPS}/eigen/include"
    "${DEPS}/zlib/include"
    "${DEPS}/expat/include"
)

target_compile_definitions(slic3r PUBLIC
    USE_TBB
    TBB_USE_CAPTURED_EXCEPTION=0
    SLIC3R_STATIC
    BOOST_ALLOW_DEPRECATED_HEADERS
    BOOST_BIND_GLOBAL_PLACEHOLDERS
)

target_compile_features(slic3r PUBLIC cxx_std_17)

# libslic3r 大量用异常和 dynamic_cast，这两个必须开
target_compile_options(slic3r PRIVATE -fexceptions -frtti)
