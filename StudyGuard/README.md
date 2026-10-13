# StudyGuard for macOS

StudyGuard is a separate focus-timer app in the Focus repository. The existing FocusGuard project is unchanged.

## Download

Download the DMG and source archive from the [StudyGuard v1.0.1 release](https://github.com/Sumi1124/Focus/releases/tag/studyguard-v1.0.1).

## Build

Requirements: macOS 13 or newer and Xcode Command Line Tools. Run `./build.sh` from this folder. It builds a universal app and writes the DMG to `releases/`.

## Browser behavior

Select Safari, Chrome, Edge, or Brave in Focus. During an active session, StudyGuard keeps the browser open and closes tabs whose URLs match the blocked-site list. Allow browser control in System Settings → Privacy & Security → Automation when asked. Other browsers stay open. Non-browser apps receive a graceful quit request.

Website blocking in the built-in Study Browser does not affect other browsers. macOS does not expose Apple's Screen Time shielding APIs to Mac apps, so StudyGuard cannot enforce system-wide app and website restrictions.

The release build is not Developer ID signed or notarized. The first launch may require Control-click → Open.
