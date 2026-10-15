# StudyGuard Update Setup

This Mac helper prepares the signature needed to offer StudyGuard 1.6.0 through **Install and Relaunch** in existing copies of StudyGuard. It is separate from the StudyGuard application and does not replace it.

Open **StudyGuard Update Setup.app** on the Mac that created StudyGuard 1.4, choose **Prepare Update**, and allow the Keychain request if macOS asks. When the helper says **Ready and copied**, paste the result into the Codex chat that is preparing the release. The result is public signature metadata. Publishing its verified enclosure in the appcast enables the existing in-app installer.

The helper downloads only the exact published 1.6.0 DMG, checks its pinned SHA-256 and length, invokes the official Sparkle 2.10.0 signing tool with the existing `com.studyguard.mac` Keychain account, and verifies the result against the public key already trusted by StudyGuard. It does not export a private key, create a replacement key, upload data, publish to GitHub, or modify the installed StudyGuard app. It copies the public signature metadata to the clipboard after successful verification. The temporary archive is removed after signing.

The helper is compiled for Apple silicon and Intel with macOS 13 or newer. Its outer app is signed locally and is not notarized, so macOS may require **Privacy & Security → Open Anyway**. The bundled official signing tool retains its original signature and Keychain identity.

`Scripts/build-update-setup.sh` packages the app; `.github/workflows/studyguard-update-setup.yml` verifies the published archive, tests rejection of mismatched signatures and modified archives, builds both architectures, checks nested signatures and runtime dependencies, and publishes the helper ZIP alongside the existing 1.6.0 release. It preserves the published StudyGuard DMG.
