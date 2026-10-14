#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SDK="$(xcrun --show-sdk-path)"
BUILD="$ROOT/work/build"
APP="$BUILD/StudyGuard.app"
OUT="$ROOT/releases"
VERSION="1.1.0"
mkdir -p "$BUILD" "$OUT"
rm -rf "$APP" "$BUILD/arm64" "$BUILD/x86_64" "$BUILD/stage"
mkdir -p "$APP/Contents/MacOS" "$BUILD/arm64" "$BUILD/x86_64"

for ARCH in arm64 x86_64; do
  swiftc -parse-as-library -swift-version 5 -target "$ARCH-apple-macos13.0" \
    -sdk "$SDK" -module-cache-path "$BUILD/module-cache-$ARCH" \
    -framework AppKit -framework SwiftUI -framework Combine -framework WebKit \
    "$ROOT/StudyGuard.swift" -o "$BUILD/$ARCH/StudyGuard"
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
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>110</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>StudyGuard checks tabs in your selected browser for blocked sites and closes only matching tabs during a focus session.</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

codesign --force --deep --sign - "$APP"
mkdir -p "$BUILD/stage"
cp -R "$APP" "$BUILD/stage/StudyGuard.app"
ln -s /Applications "$BUILD/stage/Applications"
DMG="$OUT/StudyGuard-$VERSION-macOS-universal.dmg"
rm -f "$DMG"
hdiutil create -volname "StudyGuard $VERSION" -srcfolder "$BUILD/stage" -ov -format UDZO "$DMG"
echo "Created $DMG"
