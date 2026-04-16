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

VERSION  = $(shell grep 'static let appVersion' OkJson/Utilities/Constants.swift | sed 's/.*"\(.*\)".*/\1/')
ICON_SRC = OkJson/Resources/Assets.xcassets/AppIcon.appiconset
ICONSET  = .build/AppIcon.iconset

app:
	@echo "🔨 Building OkJson..."
	@swift build
	@echo "📦 Creating app bundle..."
	@mkdir -p OkJson.app/Contents/MacOS
	@mkdir -p OkJson.app/Contents/Resources
	@cp .build/debug/OkJson OkJson.app/Contents/MacOS/
	@echo "APPL????" > OkJson.app/Contents/PkgInfo
	@echo "📎 Generating Info.plist (v$(VERSION))..."
	@sed 's/__VERSION__/$(VERSION)/g' scripts/Info.plist.template > OkJson.app/Contents/Info.plist
	@echo "🎨 Building app icon..."
	@mkdir -p $(ICONSET)
	@sips -s format png $(ICON_SRC)/16.png   --out $(ICONSET)/icon_16x16.png      >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/32.png   --out $(ICONSET)/icon_16x16@2x.png   >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/32.png   --out $(ICONSET)/icon_32x32.png      >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/64.png   --out $(ICONSET)/icon_32x32@2x.png   >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/128.png  --out $(ICONSET)/icon_128x128.png    >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/256.png  --out $(ICONSET)/icon_128x128@2x.png >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/256.png  --out $(ICONSET)/icon_256x256.png    >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/512.png  --out $(ICONSET)/icon_256x256@2x.png >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/512.png  --out $(ICONSET)/icon_512x512.png    >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/1024.png --out $(ICONSET)/icon_512x512@2x.png >/dev/null 2>&1
	@iconutil -c icns $(ICONSET) -o OkJson.app/Contents/Resources/AppIcon.icns
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
	@sed 's/__VERSION__/$(VERSION)/g' scripts/Info.plist.template > OkJson.app/Contents/Info.plist
	@mkdir -p $(ICONSET)
	@sips -s format png $(ICON_SRC)/16.png   --out $(ICONSET)/icon_16x16.png      >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/32.png   --out $(ICONSET)/icon_16x16@2x.png   >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/32.png   --out $(ICONSET)/icon_32x32.png      >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/64.png   --out $(ICONSET)/icon_32x32@2x.png   >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/128.png  --out $(ICONSET)/icon_128x128.png    >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/256.png  --out $(ICONSET)/icon_128x128@2x.png >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/256.png  --out $(ICONSET)/icon_256x256.png    >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/512.png  --out $(ICONSET)/icon_256x256@2x.png >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/512.png  --out $(ICONSET)/icon_512x512.png    >/dev/null 2>&1
	@sips -s format png $(ICON_SRC)/1024.png --out $(ICONSET)/icon_512x512@2x.png >/dev/null 2>&1
	@iconutil -c icns $(ICONSET) -o OkJson.app/Contents/Resources/AppIcon.icns
	@rm -rf .build/dmg_staging
	@mkdir -p .build/dmg_staging
	@cp -R OkJson.app .build/dmg_staging/
	@ln -s /Applications .build/dmg_staging/Applications
	@hdiutil create -volname "OkJson" -srcfolder .build/dmg_staging -ov -format UDZO -quiet OkJson-$(VERSION).dmg
	@rm -rf .build/dmg_staging
	@echo "✅ Package created: OkJson-$(VERSION).dmg"
	@ls -lh OkJson-$(VERSION).dmg

install: package
	@cp -R OkJson.app /Applications/
	@echo "✅ Installed to /Applications/OkJson.app"

uninstall:
	@rm -rf /Applications/OkJson.app
	@echo "🗑️  Uninstalled OkJson.app"
