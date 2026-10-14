# FocusGuard

FocusGuard is a small macOS study companion. Start a focus timer and it temporarily blocks distracting websites such as YouTube and Instagram across your browsers.

## Download

You do **not** need Xcode to use FocusGuard.

1. Open the repository's **Actions** tab.
2. Open the most recent **Build macOS app** workflow run.
3. Download the `FocusGuard-macOS` artifact and unzip it.
4. Open `FocusGuard.app`.

The first release is unsigned. If macOS prevents it from opening, Control-click `FocusGuard.app`, choose **Open**, then confirm **Open**.

## Features

- 15, 25, 45, 50, 60, and 90 minute focus timers
- Website blocking for YouTube and Instagram during a session
- A clear, one-click option to end a session and remove the block
- Reversible changes: FocusGuard only removes its own marked entries from your Mac's hosts file

## Privacy and permissions

FocusGuard asks for your Mac administrator password only when enabling or removing a website block. This allows the app to update `/etc/hosts`, which makes the block work in all browsers. It does not collect, upload, or share your browsing data.

## Build from source

Developers can find the source app and local build instructions in [FocusGuard/README.md](FocusGuard/README.md).

## StudyGuard

[StudyGuard](StudyGuard/README.md) is a separate macOS focus timer with a study browser that closes distracting tabs while keeping the rest of the browser open. Download its [DMG and source ZIP from the v1.4.0 release](https://github.com/Sumi1124/Focus/releases/tag/studyguard-v1.4.0).

StudyGuard 1.4.0 adds System, Light, and Dark appearance choices in Settings, with a saved preference and a charcoal palette throughout the app.
