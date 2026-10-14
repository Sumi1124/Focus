#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/BuildConfig.sh"
WORK="${STUDYGUARD_WORK:-$ROOT/work}"
OUT="${STUDYGUARD_OUT:-$ROOT/releases}"
INPUT="$WORK/update-$STUDYGUARD_VERSION"
DMG_NAME="StudyGuard-$STUDYGUARD_VERSION-macOS-universal.dmg"
SPARKLE_DIR="$(bash "$ROOT/Scripts/bootstrap-sparkle.sh")"
mkdir -p "$INPUT"
cp "$OUT/$DMG_NAME" "$INPUT/$DMG_NAME"
cat > "$INPUT/${DMG_NAME%.dmg}.html" <<HTML
<h2>StudyGuard $STUDYGUARD_VERSION</h2>
<p>Check for updates in Settings, then use Install and Relaunch to install the new version inside StudyGuard. Your local history and settings are retained.</p>
HTML
if [[ -f "$ROOT/Updates/appcast.xml" ]]; then
  cp "$ROOT/Updates/appcast.xml" "$INPUT/appcast.xml"
fi
"$SPARKLE_DIR/bin/generate_appcast" --account "$STUDYGUARD_UPDATE_KEY_ACCOUNT" \
  --download-url-prefix "https://github.com/Sumi1124/Focus/releases/download/studyguard-v$STUDYGUARD_VERSION/" \
  --embed-release-notes --maximum-deltas 0 --link "https://github.com/Sumi1124/Focus" \
  "$INPUT"
cp "$INPUT/appcast.xml" "$ROOT/Updates/appcast.xml"
printf 'Update feed with signed archive prepared at %s\n' "$ROOT/Updates/appcast.xml"
