#!/bin/bash
# OkJson 发布打包脚本
# 生成包含 App 图标和文件关联的 DMG 安装包

set -e

APP_NAME="OkJson"
BUNDLE_ID="com.okjson.app"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"

# 从 Constants.swift 读取版本号（唯一版本来源）
VERSION=$(grep 'static let appVersion' "${PROJECT_ROOT}/OkJson/Utilities/Constants.swift" \
    | sed 's/.*"\(.*\)".*/\1/')

if [ -z "$VERSION" ]; then
    echo "❌ 无法从 Constants.swift 读取版本号"
    exit 1
fi

echo "📌 版本号：${VERSION}"

APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"

cd "${PROJECT_ROOT}"

echo "🧹 清理旧构建..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 构建通用架构（arm64 + x86_64）
echo "🔨 构建 arm64..."
swift build -c release --arch arm64

echo "🔨 构建 x86_64..."
swift build -c release --arch x86_64

echo "🔗 合并通用二进制..."
mkdir -p "${BUILD_DIR}/universal"
lipo -create \
    .build/apple/Products/Release/OkJson \
    -output "${BUILD_DIR}/universal/OkJson" 2>/dev/null || \
lipo -create \
    .build/arm64-apple-macosx/release/OkJson \
    .build/x86_64-apple-macosx/release/OkJson \
    -output "${BUILD_DIR}/universal/OkJson"

echo "📦 创建 .app 包..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 复制可执行文件
cp "${BUILD_DIR}/universal/OkJson" "${APP_BUNDLE}/Contents/MacOS/"

# 写入 PkgInfo
echo "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# 生成 App 图标（icns）
echo "🎨 生成 App 图标..."
ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"
ICON_SRC="${PROJECT_ROOT}/OkJson/Resources/Assets.xcassets/AppIcon.appiconset"

# 源图标文件是 JPEG 格式（后缀为 .png），iconutil 需要真正的 PNG
for pair in "16:icon_16x16" "32:icon_16x16@2x" "32:icon_32x32" "64:icon_32x32@2x" \
            "128:icon_128x128" "256:icon_128x128@2x" "256:icon_256x256" \
            "512:icon_256x256@2x" "512:icon_512x512" "1024:icon_512x512@2x"; do
    size="${pair%%:*}"
    name="${pair##*:}"
    sips -s format png "${ICON_SRC}/${size}.png" --out "${ICONSET_DIR}/${name}.png" >/dev/null 2>&1
done

iconutil -c icns "${ICONSET_DIR}" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

# 写入完整 Info.plist（含文件关联）
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OkJson</string>
    <key>CFBundleIdentifier</key>
    <string>com.okjson.app</string>
    <key>CFBundleName</key>
    <string>OkJson</string>
    <key>CFBundleDisplayName</key>
    <string>OkJson</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>json</string>
            </array>
            <key>CFBundleTypeName</key>
            <string>JSON Document</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Default</string>
            <key>LSTypeIsPackage</key>
            <false/>
        </dict>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>xcs</string>
            </array>
            <key>CFBundleTypeName</key>
            <string>XCS Document</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Default</string>
            <key>LSTypeIsPackage</key>
            <false/>
        </dict>
    </array>
</dict>
</plist>
EOF

# 复制其他资源文件
cp -r "${PROJECT_ROOT}/OkJson/Resources/Defaults.plist" "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true
cp -r "${PROJECT_ROOT}/OkJson/Resources/Samples" "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true

# Ad-hoc 签名（未加入开发者证书，但 macOS 需要签名才能正常运行）
echo "✍️  签名..."
codesign --force --deep --sign - "${APP_BUNDLE}"

# 验证 App 包
echo "🔍 验证..."
codesign --verify --deep --strict "${APP_BUNDLE}" 2>&1 && echo "   签名验证通过" || echo "   ⚠️  签名验证失败（ad-hoc 签名在某些场景下正常）"

# 显示架构信息
echo "📐 架构信息："
file "${APP_BUNDLE}/Contents/MacOS/OkJson"

# 创建 DMG
echo "💿 创建 DMG 安装包..."
DMG_STAGING_DIR="${BUILD_DIR}/dmg_staging"
mkdir -p "${DMG_STAGING_DIR}"
cp -r "${APP_BUNDLE}" "${DMG_STAGING_DIR}/"
ln -s /Applications "${DMG_STAGING_DIR}/Applications"

hdiutil create \
    -volname "OkJson" \
    -srcfolder "${DMG_STAGING_DIR}" \
    -ov \
    -format UDZO \
    -quiet \
    "${BUILD_DIR}/${DMG_NAME}"

# 创建 ZIP（用于自动更新）
echo "📦 创建 ZIP 更新包..."
cd "${BUILD_DIR}"
ditto -c -k --keepParent "${APP_BUNDLE}" "${BUILD_DIR}/${ZIP_NAME}"
cd "${PROJECT_ROOT}"

echo ""
echo "✅ 打包完成！"
echo "   App:  ${APP_BUNDLE}"
echo "   DMG:  ${BUILD_DIR}/${DMG_NAME}"
echo "   ZIP:  ${BUILD_DIR}/${ZIP_NAME}"
ls -lh "${BUILD_DIR}/${DMG_NAME}" "${BUILD_DIR}/${ZIP_NAME}"

# 发布到 GitHub Release
echo ""
read -p "🚀 是否发布到 GitHub Release？(y/N) " PUBLISH
if [ "$PUBLISH" = "y" ] || [ "$PUBLISH" = "Y" ]; then
    TAG="v${VERSION}"

    # 检查 gh 是否可用
    if ! command -v gh &> /dev/null; then
        echo "❌ 需要安装 GitHub CLI (gh)：brew install gh"
        exit 1
    fi

    echo "📤 创建 GitHub Release ${TAG}..."
    gh release create "${TAG}" \
        "${BUILD_DIR}/${DMG_NAME}" \
        "${BUILD_DIR}/${ZIP_NAME}" \
        --title "OkJson ${TAG}" \
        --generate-notes

    echo "✅ 发布完成！用户下次启动 OkJson 将收到更新提示。"
else
    echo ""
    echo "📋 手动发布方式："
    echo "   gh release create v${VERSION} ${BUILD_DIR}/${DMG_NAME} ${BUILD_DIR}/${ZIP_NAME} --title 'OkJson v${VERSION}' --generate-notes"
fi
