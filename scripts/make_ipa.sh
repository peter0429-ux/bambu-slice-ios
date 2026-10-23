#!/usr/bin/env bash
#
# 在 macOS 上本地打未签名 ipa。
# 没有 Mac 就用 .github/workflows/build-ipa.yml 那条 GitHub Actions 路。
#
# 产物：BambuSlice-unsigned.ipa
# 未签名包不能直接装，用 Sideloadly / AltStore 签一次。
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v xcodebuild >/dev/null || { echo "没有 xcodebuild：这不是 macOS，或者没装 Xcode。"; exit 1; }
if ! command -v xcodegen >/dev/null; then
  echo "缺少 xcodegen，先执行：brew install xcodegen"
  exit 1
fi

echo "==> 生成工程"
xcodegen generate

echo "==> 编译（未签名）"
xcodebuild \
  -project BambuSlice.xcodeproj \
  -scheme BambuSlice \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  build 2>&1 | tee build.log

APP="build/Build/Products/Release-iphoneos/BambuSlice.app"
if [ ! -d "${APP}" ]; then
  echo "没找到 ${APP}"
  ls -R build/Build/Products 2>/dev/null || true
  exit 1
fi

echo "==> 打包 ipa"
rm -rf Payload BambuSlice-unsigned.ipa
mkdir -p Payload
cp -R "${APP}" Payload/
zip -qry BambuSlice-unsigned.ipa Payload

ls -lh BambuSlice-unsigned.ipa
echo
echo "下一步：用 Sideloadly 打开这个 ipa，填你的 Apple ID 签名后装到手机。"
echo "详见 docs/BUILD_IPA.md"
