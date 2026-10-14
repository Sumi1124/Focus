#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/BuildConfig.sh"
SDK="$(xcrun --show-sdk-path)"
BUILD="${STUDYGUARD_WORK:-$ROOT/work}/build-$STUDYGUARD_VERSION"
APP="$BUILD/StudyGuard.app"
OUT="${STUDYGUARD_OUT:-$ROOT/releases}"
SPARKLE_DIR="$(bash "$ROOT/Scripts/bootstrap-sparkle.sh")"
PUBLIC_KEY="$(cat "$ROOT/Updates/public-ed-key.txt")"
mkdir -p "$BUILD" "$OUT"
rm -rf "$APP" "$BUILD/arm64" "$BUILD/x86_64" "$BUILD/stage"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks" "$BUILD/arm64" "$BUILD/x86_64"
cp "$ROOT/Assets/StudyGuard.icns" "$APP/Contents/Resources/StudyGuard.icns"
cp "$ROOT/Assets/StudyGuard-1024.png" "$APP/Contents/Resources/StudyGuard-1024.png"
cp -R "$ROOT/Assets/Fonts" "$APP/Contents/Resources/Fonts"
cp "$ROOT/Assets/Sparkle-LICENSE.txt" "$APP/Contents/Resources/Sparkle-LICENSE.txt"
ditto "$SPARKLE_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"

for ARCH in arm64 x86_64; do
  swiftc -parse-as-library -swift-version 5 -target "$ARCH-apple-macos13.0" \
    -sdk "$SDK" -module-cache-path "$BUILD/module-cache-$ARCH" \
    -framework AppKit -framework SwiftUI -framework Combine -framework WebKit -framework CoreText -framework PDFKit -framework Security \
    -F "$SPARKLE_DIR" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    "$ROOT/StudyGuard.swift" "$ROOT/UI.swift" "$ROOT/Updater.swift" \
    "$ROOT/NotebookCore.swift" "$ROOT/Notebook.swift" "$ROOT/NotebookUI.swift" -o "$BUILD/$ARCH/StudyGuard"
done
lipo -create "$BUILD/arm64/StudyGuard" "$BUILD/x86_64/StudyGuard" -output "$APP/Contents/MacOS/StudyGuard"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>StudyGuard</string>
  <key>CFBundleIdentifier</key><string>com.studyguard.mac</string>
  <key>CFBundleName</key><string>StudyGuard</string>
  <key>CFBundleDisplayName</key><string>StudyGuard</string>
  <key>CFBundleIconFile</key><string>StudyGuard.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$STUDYGUARD_VERSION</string>
  <key>CFBundleVersion</key><string>$STUDYGUARD_BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>StudyGuard checks tabs in your selected browser for blocked sites and closes only matching tabs during a focus session.</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>SUFeedURL</key><string>$STUDYGUARD_UPDATE_FEED</string>
  <key>SUPublicEDKey</key><string>$PUBLIC_KEY</string>
  <key>SUEnableAutomaticChecks</key><false/>
  <key>SUAllowsAutomaticUpdates</key><false/>
  <key>SUVerifyUpdateBeforeExtraction</key><true/>
  <key>SUSendProfileInfo</key><false/>
</dict></plist>
PLIST

# Preserve the signatures supplied with Sparkle's framework and helper applications.
codesign --force --sign - "$APP"
mkdir -p "$BUILD/stage"
ditto "$APP" "$BUILD/stage/StudyGuard.app"
ln -s /Applications "$BUILD/stage/Applications"
DMG="$OUT/StudyGuard-$STUDYGUARD_VERSION-macOS-universal.dmg"
rm -f "$DMG"
hdiutil create -volname "StudyGuard $STUDYGUARD_VERSION" -srcfolder "$BUILD/stage" -ov -format UDZO "$DMG"
printf 'Created %s\n' "$DMG"
