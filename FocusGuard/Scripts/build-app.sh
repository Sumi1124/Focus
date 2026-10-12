#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release

APP="$ROOT/build/FocusGuard.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/FocusGuard" "$APP/Contents/MacOS/FocusGuard"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
echo "Created $APP"
