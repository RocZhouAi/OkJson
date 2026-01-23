.PHONY: all build test clean run app package release install

all: build

build:
	@swift build

build-release:
	@swift build -c release

test:
	@swift test --enable-code-coverage

run:
	@swift run

app:
	@echo "🔨 Building OkJson..."
	@swift build
	@echo "📦 Creating app bundle..."
	@mkdir -p OkJson.app/Contents/MacOS
	@mkdir -p OkJson.app/Contents/Resources
	@cp .build/debug/OkJson OkJson.app/Contents/MacOS/
	@echo "APPL????" > OkJson.app/Contents/PkgInfo
	@if [ ! -f OkJson.app/Contents/Info.plist ]; then \
		echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>OkJson</string><key>CFBundleIdentifier</key><string>com.okjson.app</string><key>CFBundleName</key><string>OkJson</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>1.0.0</string><key>LSMinimumSystemVersion</key><string>13.0</string><key>NSHighResolutionCapable</key><true/></dict></plist>' > OkJson.app/Contents/Info.plist; \
	fi
	@pkill OkJson 2>/dev/null || true
	@sleep 0.3
	@echo "🚀 Launching OkJson..."
	@open OkJson.app

clean:
	@rm -rf .build
	@rm -rf OkJson.app
	@rm -f OkJson-*.dmg

package: build-release
	@mkdir -p OkJson.app/Contents/MacOS
	@mkdir -p OkJson.app/Contents/Resources
	@cp .build/release/OkJson OkJson.app/Contents/MacOS/
	@echo "APPL????" > OkJson.app/Contents/PkgInfo
	@cp OkJson/Resources/Info.plist OkJson.app/Contents/ 2>/dev/null || \
		(echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>OkJson</string><key>CFBundleIdentifier</key><string>com.okjson.app</string><key>CFBundleName</key><string>OkJson</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>1.0.0</string><key>CFBundleVersion</key><string>1</string><key>LSMinimumSystemVersion</key><string>13.0</string><key>NSHighResolutionCapable</key><true/><key>NSPrincipalClass</key><string>NSApplication</string></dict></plist>' > OkJson.app/Contents/Info.plist)
	@hdiutil create -volname "OkJson" -srcfolder OkJson.app -ov -format UDZO -quiet OkJson-1.0.0.dmg
	@echo "✅ Package created: OkJson-1.0.0.dmg"
	@ls -lh OkJson-1.0.0.dmg

install: package
	@cp -R OkJson.app /Applications/
	@echo "✅ Installed to /Applications/OkJson.app"

uninstall:
	@rm -rf /Applications/OkJson.app
	@echo "🗑️  Uninstalled OkJson.app"
