#!/bin/bash
# Run on the Mac that owns StudyGuard's existing update-signing key.
# This signs the exact published 1.5.1 DMG and prints only public update metadata.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Run this on the Mac that signed StudyGuard 1.4." >&2
  exit 1
fi

task_dir="$(mktemp -d "${TMPDIR:-/tmp}/studyguard-sign.XXXXXX")"
trap 'rm -rf "$task_dir"' EXIT

version="1.5.1"
build_number="151"
dmg_name="StudyGuard-$version-macOS-universal.dmg"
dmg_sha="3741a7ed813c06cb2e211960ff8bd8eeb476b349db71a384369a80879ad8caf7"
public_key="Kqe9ZKzDzE54X6wzf1WWeQU7H7dAEbreX50EvJDcHro="
sparkle_version="2.10.0"
sparkle_sha="c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c"

echo "Downloading the published StudyGuard $version update…" >&2
curl --fail --location --silent --show-error --retry 3 \
  "https://github.com/Sumi1124/Focus/releases/download/studyguard-v$version/$dmg_name" \
  --output "$task_dir/$dmg_name"
printf '%s  %s\n' "$dmg_sha" "$task_dir/$dmg_name" | shasum -a 256 -c - >/dev/null

curl --fail --location --silent --show-error --retry 3 \
  "https://github.com/sparkle-project/Sparkle/releases/download/$sparkle_version/Sparkle-$sparkle_version.tar.xz" \
  --output "$task_dir/Sparkle.tar.xz"
printf '%s  %s\n' "$sparkle_sha" "$task_dir/Sparkle.tar.xz" | shasum -a 256 -c - >/dev/null
mkdir "$task_dir/sparkle"
tar -xf "$task_dir/Sparkle.tar.xz" -C "$task_dir/sparkle"

echo "Signing with the existing StudyGuard key in your login Keychain…" >&2
if ! signature="$("$task_dir/sparkle/bin/sign_update" --account com.studyguard.mac -p "$task_dir/$dmg_name")"; then
  printf '%s\n' "$signature" >&2
  exit 1
fi

# Verify against the public key trusted by the installed 1.4 app, rather than
# trusting that the chosen Keychain account happens to contain the correct key.
cat > "$task_dir/verify.swift" <<'SWIFT'
import Foundation
import CryptoKit

let file = CommandLine.arguments[1]
guard let publicData = Data(base64Encoded: CommandLine.arguments[2]),
      let signature = Data(base64Encoded: CommandLine.arguments[3]), signature.count == 64 else {
    fputs("The update signature is not valid Base64 metadata.\n", stderr)
    exit(1)
}
let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicData)
let archive = try Data(contentsOf: URL(fileURLWithPath: file))
guard publicKey.isValidSignature(signature, for: archive) else {
    fputs("This key does not match the update key trusted by StudyGuard 1.4. The feed has not been changed.\n", stderr)
    exit(1)
}
SWIFT
xcrun swift "$task_dir/verify.swift" "$task_dir/$dmg_name" "$public_key" "$signature"
length="$(wc -c < "$task_dir/$dmg_name" | tr -d '[:space:]')"

echo "Signature verified. Copy the JSON below into the Codex chat. It contains no private key." >&2
printf '{"version":"%s","build":"%s","length":%s,"sha256":"%s","edSignature":"%s"}\n' \
  "$version" "$build_number" "$length" "$dmg_sha" "$signature"
