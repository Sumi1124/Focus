#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/BuildConfig.sh"
CACHE="${STUDYGUARD_WORK:-$ROOT/work}/dependencies"
ARCHIVE="$CACHE/Sparkle-$STUDYGUARD_SPARKLE_VERSION.tar.xz"
DEST="$CACHE/sparkle-$STUDYGUARD_SPARKLE_VERSION"
mkdir -p "$CACHE" "$DEST"
if [[ ! -f "$ARCHIVE" ]]; then
  curl --fail --location --silent --show-error \
    "https://github.com/sparkle-project/Sparkle/releases/download/$STUDYGUARD_SPARKLE_VERSION/Sparkle-$STUDYGUARD_SPARKLE_VERSION.tar.xz" \
    --output "$ARCHIVE"
fi
printf '%s  %s\n' "$STUDYGUARD_SPARKLE_SHA256" "$ARCHIVE" | shasum -a 256 -c - >/dev/null
tar -xf "$ARCHIVE" -C "$DEST"
printf '%s\n' "$DEST"
