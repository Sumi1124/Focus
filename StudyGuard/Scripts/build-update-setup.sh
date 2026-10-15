#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPARKLE_DIR="$(bash "$ROOT/Scripts/bootstrap-sparkle.sh")"
OUT="$ROOT/releases"
WORK="$ROOT/work/update-setup"
APP="$WORK/StudyGuard Update Setup.app"
mkdir -p "$OUT" "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"

for architecture in arm64 x86_64; do
  swiftc -parse-as-library -swift-version 5 -target "$architecture-apple-macos13.0" \
    -framework AppKit -framework CryptoKit \
    "$ROOT/UpdateSetup/UpdateSetupCore.swift" "$ROOT/UpdateSetup/UpdateSetup.swift" \
    -o "$WORK/UpdateSetup-$architecture"
done
lipo -create "$WORK/UpdateSetup-arm64" "$WORK/UpdateSetup-x86_64" -output "$APP/Contents/MacOS/UpdateSetup"
ditto "$SPARKLE_DIR/bin/sign_update" "$APP/Contents/Helpers/sign_update"
cp "$ROOT/Assets/Sparkle-LICENSE.txt" "$APP/Contents/Resources/Sparkle-LICENSE.txt"
if [[ -f "$ROOT/Assets/StudyGuard.icns" ]]; then
  cp "$ROOT/Assets/StudyGuard.icns" "$APP/Contents/Resources/StudyGuard.icns"
fi
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>UpdateSetup</string>
<key>CFBundleIdentifier</key><string>com.studyguard.mac.update-setup</string>
<key>CFBundleName</key><string>StudyGuard Update Setup</string>
<key>CFBundleDisplayName</key><string>StudyGuard Update Setup</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>StudyGuard.icns</string>
<key>CFBundleShortVersionString</key><string>1.6.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Keep the original official signer's signature and Keychain identity.
codesign --verify --strict "$APP/Contents/Helpers/sign_update"
lipo "$APP/Contents/Helpers/sign_update" -verify_arch arm64 x86_64
"$APP/Contents/Helpers/sign_update" --help > "$WORK/signer-help.txt"
otool -L "$APP/Contents/Helpers/sign_update"
if otool -L "$APP/Contents/Helpers/sign_update" | rg '@rpath|@executable_path|@loader_path'; then
  echo 'The signing tool has an unbundled runtime dependency.' >&2
  exit 1
fi
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
lipo "$APP/Contents/MacOS/UpdateSetup" -verify_arch arm64 x86_64
ZIP="$OUT/StudyGuard-1.6.0-Update-Setup-macOS-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(cd "$OUT" && shasum -a 256 "$(basename "$ZIP")" > StudyGuard-1.6.0-Update-Setup-SHA256.txt)
printf 'Built %s\n' "$ZIP"
