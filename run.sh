#!/bin/bash
# OkJson 快捷运行脚本

set -e

echo "🔨 Building OkJson..."
swift build

if [ $? -eq 0 ]; then
    echo "✅ Build successful"

    # Kill existing instance
    pkill OkJson 2>/dev/null || true
    sleep 0.3

    # Update app bundle
    mkdir -p OkJson.app/Contents/MacOS
    mkdir -p OkJson.app/Contents/Resources
    cp .build/debug/OkJson OkJson.app/Contents/MacOS/

    # Ensure Info.plist exists
    if [ ! -f OkJson.app/Contents/Info.plist ]; then
        cat > OkJson.app/Contents/Info.plist << 'EOF'
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
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
    fi

    echo "APPL????" > OkJson.app/Contents/PkgInfo

    echo "🚀 Launching OkJson..."
    open OkJson.app

    echo "Done!"
else
    echo "❌ Build failed"
    exit 1
fi
