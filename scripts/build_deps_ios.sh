#!/usr/bin/env bash
#
# 交叉编译 libslic3r 依赖到 iOS arm64。
#
# ⚠️ 这是模板，不是一键脚本。我在 Windows 上写的，没法在 macOS 上实跑验证。
#    第一次执行大概率会在某个依赖上失败，报错点一般就是版本号或
#    CMake 变量名对不上。按提示改，别指望它一次过。
#
# ⚠️ 版本号务必对照你 checkout 的 Bambu Studio 里 deps/ 目录锁定的版本，
#    不要直接用下面的默认值。版本不匹配会出现诡异的模板报错。
#
# 产物落在 Frameworks/<name>/{include,lib}
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FW="${ROOT}/Frameworks"
WORK="${ROOT}/vendor"
DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-16.0}"
SYSROOT="$(xcrun --sdk iphoneos --show-sdk-path)"
JOBS="$(sysctl -n hw.ncpu)"

# 默认版本仅作示例，请改成 Bambu Studio 里锁定的版本
BOOST_VERSION="${BOOST_VERSION:-1.83.0}"
TBB_VERSION="${TBB_VERSION:-v2021.11.0}"
ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}"
EXPAT_VERSION="${EXPAT_VERSION:-2.6.0}"

mkdir -p "${FW}" "${WORK}"

log() { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }

fetch() {  # fetch <url> <dest-dir>
  local url="$1" dest="$2"
  if [ -d "${dest}" ]; then
    log "已存在，跳过下载: ${dest}"
    return
  fi
  log "下载 ${url}"
  curl -L --fail --retry 3 -o "${dest}.tmp" "${url}"
  mkdir -p "${dest}"
  tar -xf "${dest}.tmp" -C "${dest}" --strip-components=1
  rm -f "${dest}.tmp"
}

# ─────────────────────────────────────────────────────────────
# Eigen：纯头文件，直接拷
# ─────────────────────────────────────────────────────────────
build_eigen() {
  log "Eigen (header-only)"
  fetch "https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.tar.gz" "${WORK}/eigen"
  mkdir -p "${FW}/eigen/include"
  rm -rf "${FW}/eigen/include/Eigen"
  cp -R "${WORK}/eigen/Eigen" "${FW}/eigen/include/"
}

# ─────────────────────────────────────────────────────────────
# zlib / expat：CMake 一把梭
# ─────────────────────────────────────────────────────────────
build_zlib() {
  log "zlib ${ZLIB_VERSION}"
  fetch "https://zlib.net/fossils/zlib-${ZLIB_VERSION}.tar.gz" "${WORK}/zlib"

  # 不能用 -G Xcode：它会给 example / minigzip 生成 App target，
  # 然后卡在「requires a development team」上。Makefile 生成器没这问题。
  cmake -S "${WORK}/zlib" -B "${WORK}/zlib/build-ios" \
        -DCMAKE_TOOLCHAIN_FILE="${ROOT}/scripts/ios.toolchain.cmake" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF

  # 只编静态库，跳过命令行工具
  cmake --build "${WORK}/zlib/build-ios" -j"${JOBS}" --target zlibstatic --config Release

  mkdir -p "${FW}/zlib/include" "${FW}/zlib/lib"
  local lib zconf
  lib="$(find "${WORK}/zlib/build-ios" -name 'libz*.a' -type f | head -1)"
  [ -n "${lib}" ] || { echo "没找到 libz.a"; return 1; }
  cp "${lib}" "${FW}/zlib/lib/libz.a"

  # zconf.h 是 CMake 从 zconf.h.in 生成到 build 目录的，源码树里没有
  zconf="$(find "${WORK}/zlib" -maxdepth 2 -name 'zconf.h' -type f | head -1)"
  cp "${WORK}/zlib/zlib.h" "${FW}/zlib/include/"
  [ -n "${zconf}" ] && cp "${zconf}" "${FW}/zlib/include/"
  log "zlib 完成: ${FW}/zlib"
}

build_expat() {
  log "expat ${EXPAT_VERSION}"
  fetch "https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_VERSION//./_}/expat-${EXPAT_VERSION}.tar.gz" "${WORK}/expat"
  cmake -S "${WORK}/expat" -B "${WORK}/expat/build-ios" -G Xcode \
        -DCMAKE_TOOLCHAIN_FILE="${ROOT}/scripts/ios.toolchain.cmake" \
        -DCMAKE_INSTALL_PREFIX="${FW}/expat" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
        -DEXPAT_SHARED_LIBS=OFF \
        -DEXPAT_BUILD_TOOLS=OFF \
        -DEXPAT_BUILD_EXAMPLES=OFF \
        -DEXPAT_BUILD_TESTS=OFF
  cmake --build "${WORK}/expat/build-ios" --config Release --target install
}

# ─────────────────────────────────────────────────────────────
# TBB：libslic3r 的并行循环全靠它。必须静态、必须关掉它自己的测试
# ─────────────────────────────────────────────────────────────
build_tbb() {
  log "TBB ${TBB_VERSION}"
  fetch "https://github.com/oneapi-src/oneTBB/archive/refs/tags/${TBB_VERSION}.tar.gz" "${WORK}/tbb"

  # oneTBB 的 cmake_minimum_required 写的是 3.1，CMake 4 直接拒绝，
  # 用 CMAKE_POLICY_VERSION_MINIMUM 把兼容性下限放回去。
  cmake -S "${WORK}/tbb" -B "${WORK}/tbb/build-ios" \
        -DCMAKE_TOOLCHAIN_FILE="${ROOT}/scripts/ios.toolchain.cmake" \
        -DCMAKE_INSTALL_PREFIX="${FW}/tbb" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DTBB_BUILD_SHARED=OFF \
        -DTBB_BUILD_STATIC=ON \
        -DTBB_TEST=OFF \
        -DTBB_STRICT=OFF
  cmake --build "${WORK}/tbb/build-ios" -j"${JOBS}" --config Release --target install
}

# ─────────────────────────────────────────────────────────────
# Boost：b2 自带 iOS 支持，比 CMake 靠谱。
# 只编 libslic3r 真正用到的几个库，全编要跑一小时。
# ─────────────────────────────────────────────────────────────
build_boost() {
  log "Boost ${BOOST_VERSION} (filesystem/thread/system/regex/iostreams)"
  fetch "https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION//./_}.tar.gz" "${WORK}/boost"

  pushd "${WORK}/boost" >/dev/null
  ./bootstrap.sh --with-libraries=filesystem,thread,system,regex,iostreams --prefix="${FW}/boost" >/dev/null

  # 单独写一份 user-config，避免在命令行里塞带引号的多行参数
  cat > "${WORK}/ios-user-config.jam" <<EOF
using clang : ios
: xcrun -sdk iphoneos clang++
: <compileflags>"-arch arm64 -miphoneos-version-min=${DEPLOYMENT_TARGET} -isysroot ${SYSROOT} -std=c++17 -fPIC"
  <linkflags>"-arch arm64 -miphoneos-version-min=${DEPLOYMENT_TARGET} -isysroot ${SYSROOT}"
;
EOF

  # target-os=iphone 是 b2 交叉到 iOS 的关键。
  # 注意：不能再写 abi=iphone —— <abi> 只接受 aapcs/eabi/ms/n32/o32/sysv 这些，
  # 写上会直接报 "iphone is not a known value of feature <abi>"。
  ./b2 -j"${JOBS}" \
      toolset=clang-ios \
      target-os=iphone \
      architecture=arm \
      address-model=64 \
      binary-format=mach-o \
      variant=release \
      link=static \
      runtime-link=static \
      threading=multi \
      cxxstd=17 \
      --user-config="${WORK}/ios-user-config.jam" \
      install 2>&1 | tail -40

  popd >/dev/null
}

# ─────────────────────────────────────────────────────────────
# CGAL：头文件为主。libslic3r 用到精确谓词时会要 GMP/MPFR，
# 这两个在 iOS 上编起来最烦。先试纯头文件模式，编不过再补 GMP。
# ─────────────────────────────────────────────────────────────
build_cgal() {
  log "CGAL (header-only, 不含 GMP/MPFR)"
  fetch "https://github.com/CGAL/cgal/releases/download/v5.6.1/CGAL-5.6.1.tar.xz" "${WORK}/cgal"
  mkdir -p "${FW}/cgal/include"
  cp -R "${WORK}/cgal/include/CGAL" "${FW}/cgal/include/"
  echo "提示：若编译时报 GMP/MPFR 缺失，需另编 gmp+mpfr 并放到 Frameworks/gmp。"
}

case "${1:-all}" in
  eigen)  build_eigen ;;
  zlib)   build_zlib ;;
  expat)  build_expat ;;
  tbb)    build_tbb ;;
  boost)  build_boost ;;
  cgal)   build_cgal ;;
  all)
    build_eigen
    build_zlib
    build_expat
    build_tbb
    build_boost
    build_cgal
    log "依赖构建结束。产物：${FW}"
    ;;
  *)
    echo "用法: $0 [all|eigen|zlib|expat|tbb|boost|cgal]"
    exit 1
    ;;
esac
