#!/bin/bash
# Release automation script for OkJson

VERSION="1.0.0"
BUILD_DIR=".build/release"
APP_NAME="OkJson"

echo "🔨 Building release version..."
swift build -c release

echo "📦 Creating .app bundle..."
mkdir -p ${APP_NAME}.app/Contents/{MacOS,Resources}
cp ${BUILD_DIR}/${APP_NAME} ${APP_NAME}.app/Contents/MacOS/

cat > ${APP_NAME}.app/Contents/Info.plist << 'EOF'
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
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "APPL????" > ${APP_NAME}.app/Contents/PkgInfo
cp -r OkJson/Resources/* ${APP_NAME}.app/Contents/Resources/ 2>/dev/null || true

echo "💿 Creating DMG..."
hdiutil create -volname "OkJson" -srcfolder ${APP_NAME}.app -ov -format UDZO ${APP_NAME}-${VERSION}.dmg

echo "✅ Release complete: ${APP_NAME}-${VERSION}.dmg"
ls -lh ${APP_NAME}-${VERSION}.dmg
