# In-app updates

StudyGuard 1.3.0 and newer use [Sparkle](https://sparkle-project.org/documentation/) for the Check for Updates button, download, signature validation, replacement, and relaunch. Install 1.3.0 once to gain the updater; 1.2.0 and older have only the manual release-page checker.

The update feed is `https://raw.githubusercontent.com/Sumi1124/Focus/main/StudyGuard/Updates/appcast.xml`. It references signed DMGs in GitHub Releases. Public key: `public-ed-key.txt`. The private Ed25519 signing key stays in the macOS login Keychain under the account `com.studyguard.mac`; it is not part of this source tree or source ZIP. Back up your Keychain securely. Do not export the private key into the repository.

Automatic checking is off by default and can be enabled in Settings. Installation and relaunch require the user's action. The update button is disabled while a study session is running. App termination saves the current session through the existing model.

## StudyGuard 1.6.0 announcement

The feed announces 1.6.0 using Sparkle's supported informational update format: a version and release-page link with no archive enclosure. Installed copies of 1.4.0 can discover it through **Check for Updates** and open **Learn More…** to download the DMG. Quit the app and replace it in Applications to install this release; saved settings and history are retained.

The signing key is not available in GitHub Actions, so 1.6.0 is not offered for automatic download/install/relaunch. Existing signed 1.4.0 and 1.3.0 feed entries and the public key are retained. On the signing Mac, sign the exact published 1.6.0 DMG and replace its informational entry with the generated signed enclosure to enable in-app installation. Do not rebuild the archive between signing and publication.

On the Mac that signed 1.4, run `bash Scripts/sign-published-update.sh`. The helper downloads the exact published 1.6.0 archive, verifies its SHA-256, uses the existing `com.studyguard.mac` Keychain account through Sparkle's pinned signing tool, and verifies the signature against the public key already trusted by 1.4. It prints public JSON metadata for publishing the signed enclosure. It does not export the private key or change the archive or feed.

## Publishing the next version

1. Increment both the visible version and build number in `BuildConfig.sh`.
2. Build with `bash build.sh`; the Sparkle distribution is pinned by version and SHA-256. The bundle embeds Sparkle, the public key, and the feed URL.
3. On the signing Mac, run `bash Scripts/prepare-update.sh`. This uses the key in Keychain and Sparkle's `generate_appcast` tool. Set `STUDYGUARD_WORK` and `STUDYGUARD_OUT` when using the repository-level work/output directories.
4. Publish the source commit and GitHub release `studyguard-v<version>`, and upload the exact DMG used by the signing script. Rebuilding or modifying the DMG after signing requires a new signature.
5. Publish `Updates/appcast.xml` only after the referenced release asset is available. Keep previous eligible entries when increasing the minimum macOS version. Do not add an unsigned old DMG to the feed.

The update archive's EdDSA signature is checked before extraction. The signing process follows [Sparkle's publishing guide](https://sparkle-project.org/documentation/publishing/). Sparkle's bundled helper signatures are preserved on its framework and helper applications; the enclosing app is locally signed. Apple Developer ID signing and notarization remain a separate distribution step.

For a fork, use your own feed URL and signing key. Anyone can build this source, but only the signing-key owner can publish an update trusted by this app.

An app opened from a read-only DMG must first be copied to Applications or another writable installation folder. macOS may request administrator authorization if replacing an app in a protected location.

The universal app was built and the update archive was signed. The download/install/relaunch lifecycle has not been tested end to end.
