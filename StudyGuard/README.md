# StudyGuard for macOS

StudyGuard is a separate focus-timer app in the Focus repository. The existing FocusGuard project is unchanged.

## Download

Download the DMG and source archive from the [StudyGuard v1.0.2 release](https://github.com/Sumi1124/Focus/releases/tag/studyguard-v1.0.2).

## Features

- Focus time today, total focus time, and sessions started, stored locally on your Mac.
- Settings includes a GitHub release check. When an update is found, the release page provides the DMG for download and manual installation.
- The updater checks the latest StudyGuard release at GitHub; it does not silently replace the app.

## Build

Requirements: macOS 13 or newer and Xcode Command Line Tools. Run `./build.sh` from this folder. It builds a universal app and writes the DMG to `releases/`.

## Browser behavior

Select Safari, Chrome, Edge, or Brave in Focus. During an active session, StudyGuard keeps the browser open and closes tabs whose URLs match the blocked-site list. Allow browser control in System Settings → Privacy & Security → Automation when asked. Other browsers stay open. Non-browser apps receive a graceful quit request.

Website blocking in the built-in Study Browser does not affect other browsers. macOS does not expose Apple's Screen Time shielding APIs to Mac apps, so StudyGuard cannot enforce system-wide app and website restrictions.

The release build is not Developer ID signed or notarized. The first launch may require Control-click → Open.
