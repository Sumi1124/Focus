# FocusGuard

A small native macOS focus app: choose a timer, block YouTube and Instagram while studying, and unblock them at the end.

## Download and open it (no Xcode needed)

Each update to `main` automatically builds a downloadable Mac app in the repository's **Actions** tab. Open the latest **Build macOS app** run, download the `FocusGuard-macOS` artifact, unzip it, and double-click `FocusGuard.app`.

The first version is unsigned because Apple code signing and notarization require the app owner's Apple Developer credentials. If macOS blocks the first launch, Control-click the app, choose **Open**, then confirm **Open**. No Xcode is needed to use the app.

## Build it yourself

On a Mac with Xcode 15 or later installed:

```bash
cd FocusGuard
chmod +x Scripts/build-app.sh
Scripts/build-app.sh
```

This creates `build/FocusGuard.app`, which can be double-clicked. To share it with other people, distribute a signed and notarized `.dmg`; unsigned apps commonly need an extra Gatekeeper confirmation.

## How the block works

When a session starts, FocusGuard requests the Mac administrator password, then adds only a clearly marked `FocusGuard` section to `/etc/hosts`. It removes that same section when the session ends or when **Remove FocusGuard website block** is pressed. It never removes other hosts-file entries.

The block applies to all browsers. Existing browser tabs may need to be refreshed. It is intended as a personal study aid, not a parental-control or security system.
