#!/bin/bash
# 打包「活着」为 DMG:Release 构建 → 暂存目录(含 /Applications 快捷方式)→ 压缩镜像。
# 用法: ./make-dmg.sh [签名身份]  —— 默认用 Xcode 自动签名,失败可 ./make-dmg.sh "-"
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="活着"
PROJECT="Live.xcodeproj"
SCHEME="Live"
BUILD_DIR="build"
VOL_NAME="${APP_NAME}"

echo "==> Release 构建"
SIGN_ARGS=()
if [ "${1:-}" != "" ]; then
  SIGN_ARGS=(CODE_SIGN_IDENTITY="$1" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO)
fi
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$BUILD_DIR" build ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} 2>&1 | tail -5

# defaults 读 plist 需要绝对路径,相对路径会被当成域名而读到失败。
APP_PATH="$(pwd)/$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"
[ -d "$APP_PATH" ] || { echo "!! 找不到 $APP_PATH"; exit 1; }

VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
# 包名统一用英文 live-v<版本>.dmg,和 GitHub Release 里的资产名一致。
OUT_DMG="live-v${VERSION}.dmg"

echo "==> 准备 DMG 内容(带 /Applications 拖拽快捷方式)"
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> 生成 $OUT_DMG"
rm -f "$OUT_DMG"
hdiutil create -volname "$VOL_NAME" \
  -srcfolder "$STAGING" \
  -ov -format UDZO "$OUT_DMG" >/dev/null

hdiutil verify "$OUT_DMG" >/dev/null && echo "==> 校验通过"
echo "==> 完成: $(pwd)/$OUT_DMG ($(du -h "$OUT_DMG" | cut -f1 | tr -d ' '))"
