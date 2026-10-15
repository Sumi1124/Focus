# StudyGuard for macOS

StudyGuard is a macOS study timer with app and tab controls and a separate study browser.

Version 1.2.0 implements the paper-and-ink Penpot design: a large timer, simple navigation, History rows and charts, separate Distractions and Settings sheets, and a custom bookmarked-page app icon. Libre Baskerville and IBM Plex fonts are bundled under their SIL Open Font Licenses in `Assets/Fonts`.

Version 1.3.0 adds in-app updates using Sparkle. Install this version once, then use Settings → Check for updates and follow the Install and Relaunch window for future versions. Automatic checks are optional. Updates are signed and verified before extraction; history and settings remain local.

Version 1.4.0 adds dark mode. Choose System, Light, or Dark in Settings; your preference is saved. The charcoal palette covers every app screen and sheet. System follows your Mac’s appearance.

Version 1.5 adds Study Notebook to the sidebar, with SourceDesk-inspired source collection, saved notes, source-based AI chat, summaries, key points, quizzes, and flashcards. Focus and break timers also survive quitting and reopening the app. Version 1.5.1 verifies that the chosen Ollama model runs locally before sending source excerpts.

## What it does

- Focus sessions for 25, 50, or 90 minutes.
- During a session, selected Safari, Chrome, Edge, and Brave apps stay open; only tabs matching your blocked-site list are closed. Other selected apps receive a graceful quit request.
- A built-in browser blocks domains on your list. YouTube and Instagram are included by default.
- A personal focus dashboard tracks focus time today, all-time focus time, and sessions started. The history stays on your Mac.
- The selected timer and active session are saved locally. If you quit and reopen StudyGuard, the timer resumes from its saved end time; app and tab controls only run while StudyGuard is open.
- Name each focus session, edit the daily goal beside the timer, and review a seven-day chart and your last eight sessions in History.
- Take a 5, 10, or 15 minute break with app and browser controls paused. Study Browser continues to use its site list.
- Settings and the StudyGuard menu include Check for Updates. New versions can be downloaded, installed, and relaunched inside the app. Finish an active focus session before updating.
- Your app list and blocked domains are stored locally in your Mac user account.
- Study Notebook imports PDF, TXT, Markdown, RTF, website text, and pasted text. Citation buttons open the exact saved excerpt, with PDF page numbers where available.
- Keep multiple notebooks, write notes, ask questions, generate summaries and key points, take multiple-choice quizzes, and flip through flashcards. Sources and notes work without AI; chat and generation use your chosen Ollama or Groq provider.

## Study Notebook

Version 1.6 adds **AI Settings → Provider → Groq (cloud)** with a masked API key field, **Save key**, and **Remove key**. Create a free API key at [Groq Console](https://console.groq.com/keys), paste it, save it, and choose **Check connection**. The key stays in your Mac's Keychain. Groq's free tier has usage limits and supported models can change; the default is `llama-3.1-8b-instant`. No Ollama installation is needed for Groq. The app asks before sending selected source excerpts, your question, and recent chat to Groq, separately for each notebook. **Reset cloud permission** makes it ask again.


Choose **Study Notebook** in the sidebar. Use the notebook menu to create or rename a notebook. Add sources with **Add source**, then use **Chat**, **Notes**, or **Study tools**. The focus timer keeps running while you study in the notebook, and its countdown links back to Session.

For local AI with Ollama selected, install and open [Ollama](https://ollama.com/download/mac), download a local model (for example, `ollama pull llama3.2`), and choose **Check connection**. Pick an installed model or enter its name. AI requests go only to Ollama on this Mac at `127.0.0.1:11434`; hosted Ollama models are excluded and rejected before source text is sent. There is no cloud AI provider or API key in this version. Website imports contact the URL you add.

Notebook data is stored in `~/Library/Application Support/com.studyguard.mac/notebooks.json`, with atomic writes. **Export notebook** creates a readable JSON backup containing sources, notes, conversations, and study materials. The AI works from selected excerpts, rather than every word in long documents. Check citations; AI answers and generated quiz answers can contain mistakes. Documents are limited to 20 MB, websites to 2 MB, and source text to 500,000 characters. Scanned PDFs need readable text from an OCR tool; websites that require JavaScript or login may need pasted text.

## Important limits

macOS does not expose Apple's Screen Time shielding APIs to Mac apps. StudyGuard therefore cannot block an app or website system-wide. Add Safari, Chrome, Edge, or Brave in Focus to have its matching tabs closed during sessions. Browser tab closing requires allowing StudyGuard to control the selected browser in System Settings → Privacy & Security → Automation. Unsupported browsers stay open; StudyGuard does not close the whole browser. Other app closure is a graceful quit request and a user can cancel it. The focus guard only runs while StudyGuard is open. The Study Browser also enforces the site list itself.

## Install

Open the latest `StudyGuard-<version>-macOS-universal.dmg`, then drag StudyGuard to Applications. This build is not Developer ID signed or notarized, so the first launch may require Control-click → Open. It is an open-source build intended for direct GitHub distribution and personal use.

## Build from source

Requirements: macOS 13 or newer and Xcode Command Line Tools.

Run `bash build.sh` from the StudyGuard folder. The script fetches the pinned Sparkle framework from its official release, verifies its SHA-256, compiles arm64 and Intel builds, combines them into a universal app, signs it locally with an ad-hoc signature, and creates the DMG in `releases/`. Sparkle's supplied signatures are preserved. Internet access is required for the first build.

Focus history, session topics, and goals stay on your Mac. The updater contacts the GitHub-hosted update feed and downloads signed release assets; Study Browser loads websites directly using WebKit. See [Updates/README.md](Updates/README.md) for future publishing and signing instructions.

## GitHub release

Download the DMG and standalone source archive from [StudyGuard v1.6.0](https://github.com/Sumi1124/Focus/releases/tag/studyguard-v1.6.0).

The GitHub Actions StudyGuard workflow checks notebook and timer behavior, compiles both Mac architectures, and publishes the DMG, source archive, and checksums. In installed copies of 1.4.0 and 1.5.1, **Check for Updates** announces 1.6.0 and **Learn More…** starts the installer download in the default browser without visiting the GitHub release page. Install this release manually by downloading the DMG and replacing the app in Applications. Automatic installation through Sparkle requires the private key on the signing Mac; previous signed feed entries and the public key are retained.

Recent session history starts with version 1.1.0; previously recorded total focus time remains available. Active timers are saved on each tick, quit, and Mac sleep. A timer keeps its original end time while the app is closed; on reopening, a finished focus session is added to history once. App and tab controls run only while StudyGuard is open.
