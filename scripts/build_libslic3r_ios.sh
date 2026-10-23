#!/usr/bin/env bash
#
# 把 Bambu Studio 的 libslic3r 编成 iOS 静态库（不含 GUI）。
#
# ⚠️ 同样只是模板。这一步是整个移植里最花时间的部分，期望值：
#    - 顺利的话，配置 + 编译 2~4 小时（含调试 CMake 报错）
#    - 第一次几乎一定会在 find_package 或源码排除上失败
#
# 核心思路：
#   1. 用他们自己的顶层 CMakeLists，但关掉 GUI / 测试 / 网络 / 云
#   2. 依赖不让他们自动下载（那套逻辑只认 macOS/Windows 桌面）
#      而是指向我们自己编好的 Frameworks/
#   3. 只 build libslic3r 这一个 target，不 build BambuStudio.app
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FW="${ROOT}/Frameworks"
SRC="${ROOT}/vendor/BambuStudio"
BUILD="${SRC}/build-ios"
TAG="${BAMBU_TAG:-v01.09.00.00}"   # 改成你要跟的 tag

log() { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }

# ── 1. 取源码 ────────────────────────────────────────────────
if [ ! -d "${SRC}/src/libslic3r" ]; then
  log "clone BambuStudio @ ${TAG}"
  mkdir -p "${ROOT}/vendor"
  git clone --depth 1 --branch "${TAG}" \
      https://github.com/bambulab/BambuStudio.git "${SRC}"
else
  log "源码已存在: ${SRC}"
fi

# ── 2. 准备依赖目录（Bambu 的 CMake 期望 deps 在固定位置）────
log "把编好的依赖软链到 deps 期望的位置"
mkdir -p "${SRC}/deps/build"
for dep in boost tbb eigen zlib expat cgal gmp; do
  if [ -d "${FW}/${dep}" ]; then
    ln -sfn "${FW}/${dep}" "${SRC}/deps/build/${dep}" || true
  fi
done

# ── 3. 配置 ──────────────────────────────────────────────────
log "configure"
mkdir -p "${BUILD}"
cd "${BUILD}"

cmake "${SRC}" -G Xcode \
  -DCMAKE_TOOLCHAIN_FILE="${ROOT}/scripts/ios.toolchain.cmake" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="${FW}/boost;${FW}/tbb;${FW}/eigen;${FW}/zlib;${FW}/expat;${FW}/cgal" \
  \
  -DSLIC3R_GUI=OFF \
  -DSLIC3R_STATIC=1 \
  -DSLIC3R_PCH=OFF \
  -DSLIC3R_FHS=OFF \
  -DBUILD_TESTS=OFF \
  -DSLIC3R_BUILD_TESTS=OFF \
  \
  -DBUILD_SHARED_LIBS=OFF \
  -DUSE_TBB=ON \
  -DUSE_SYSTEM_EIGEN=ON \
  -DUSE_SYSTEM_CGAL=ON \
  \
  -DENABLE_CLOUD_SERVICE=OFF \
  -DENABLE_UPDATE_CHECK=OFF \
  -DENABLE_PLUGIN_UPDATE=OFF \
  2>&1 | tee configure.log || {
    echo
    echo "配置失败。看 docs/PORTING.md 的「常见报错」一节，"
    echo "绝大多数是 find_package(Boost/TBB) 找不到我们编的 iOS 版本。"
    exit 1
  }

# ── 4. 只编 libslic3r ────────────────────────────────────────
log "build libslic3r（这一步最慢）"
xcodebuild -project BambuStudio.xcodeproj \
           -target libslic3r \
           -configuration Release \
           -sdk iphoneos \
           -arch arm64 \
           ONLY_ACTIVE_ARCH=NO \
           CODE_SIGNING_ALLOWED=NO \
           build 2>&1 | tee build.log | tail -60

# ── 5. 收集产物 ──────────────────────────────────────────────
log "收集 libslic3r.a 与头文件"
mkdir -p "${FW}/libslic3r/lib" "${FW}/libslic3r/include"

LIB_PATH="$(find "${BUILD}" -name 'libslic3r.a' -type f | head -1)"
if [ -z "${LIB_PATH}" ]; then
  echo "没找到 libslic3r.a，编译没成功。看 ${BUILD}/build.log"
  exit 1
fi
cp "${LIB_PATH}" "${FW}/libslic3r/lib/"
cp -R "${SRC}/src/libslic3r" "${FW}/libslic3r/include/"

log "完成：${FW}/libslic3r"
echo
echo "下一步：把 project.yml 里的 BAMBU_CORE_ENABLED 从 0 改成 1，"
echo "并按注释补上 HEADER_SEARCH_PATHS / OTHER_LDFLAGS，然后 xcodegen generate。"
