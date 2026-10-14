# StudyGuard for macOS

StudyGuard is a macOS study timer with app and tab controls and a separate study browser.

Version 1.2.0 implements the paper-and-ink Penpot design: a large timer, simple navigation, History rows and charts, separate Distractions and Settings sheets, and a custom bookmarked-page app icon. Libre Baskerville and IBM Plex fonts are bundled under their SIL Open Font Licenses in `Assets/Fonts`.

## What it does

- Focus sessions for 25, 50, or 90 minutes.
- During a session, selected Safari, Chrome, Edge, and Brave apps stay open; only tabs matching your blocked-site list are closed. Other selected apps receive a graceful quit request.
- A built-in browser blocks domains on your list. YouTube and Instagram are included by default.
- A personal focus dashboard tracks focus time today, all-time focus time, and sessions started. The history stays on your Mac.
- Name each focus session, edit the daily goal beside the timer, and review a seven-day chart and your last eight sessions in History.
- Take a 5, 10, or 15 minute break with app and browser controls paused. Study Browser continues to use its site list.
- Settings includes a GitHub update check and opens the release page when a newer version is available.
- Your app list and blocked domains are stored locally in your Mac user account.

## Important limits

macOS does not expose Apple's Screen Time shielding APIs to Mac apps. StudyGuard therefore cannot block an app or website system-wide. Add Safari, Chrome, Edge, or Brave in Focus to have its matching tabs closed during sessions. Browser tab closing requires allowing StudyGuard to control the selected browser in System Settings → Privacy & Security → Automation. Unsupported browsers stay open; StudyGuard does not close the whole browser. Other app closure is a graceful quit request and a user can cancel it. The focus guard only runs while StudyGuard is open. The Study Browser also enforces the site list itself.

## Install

Open the latest `StudyGuard-<version>-macOS-universal.dmg`, then drag StudyGuard to Applications. This build is not Developer ID signed or notarized, so the first launch may require Control-click → Open. It is an open-source build intended for direct GitHub distribution and personal use.

## Build from source

Requirements: macOS 13 or newer and Xcode Command Line Tools.

Run `bash build.sh` from the StudyGuard folder. The script compiles arm64 and Intel builds, combines them into a universal app, signs it locally with an ad-hoc signature, and creates the DMG in `releases/`.

Focus history, session topics, and goals stay on your Mac. Settings contacts GitHub when you check for an update; Study Browser loads websites directly using WebKit.

## GitHub release

Download the DMG and standalone source archive from [StudyGuard v1.2.0](https://github.com/Sumi1124/Focus/releases/tag/studyguard-v1.2.0).

Recent session history starts with version 1.1.0; previously recorded total focus time remains available. Regular quits and Mac sleep save an active session.
