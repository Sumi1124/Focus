# StudyGuard 1.5.1 — Study Notebook

- Adds a Study Notebook section to the sidebar, inspired by SourceDesk.
- Collect PDF, TXT, Markdown, RTF, website, and pasted-text sources in multiple local notebooks.
- Write saved notes and ask questions with a local Ollama model. Citation buttons show the saved source excerpts and PDF page numbers.
- Generate summaries, key points, interactive quizzes, and flashcards. Generated study materials are saved with the notebook.
- Export notebooks to readable JSON backups, including sources, notes, chat, and study tools.
- Preserves selected timer settings and running focus/break sessions across app restarts. The countdown uses its original end time; sessions that finish while closed are recorded once on reopening.
- Shows a link to the running timer inside Study Notebook.
- Lists only downloaded local Ollama models and verifies the selected model before sending source text. Hosted Ollama models are not supported.

Sources and notes work without a model. For AI tools, install and open Ollama, download a model such as `llama3.2`, then choose Check connection in Study Notebook. AI uses selected excerpts and may make mistakes; inspect the citations as you study.

Requires macOS 13 or newer on Apple silicon or Intel. Download the DMG, quit StudyGuard, and replace the app in Applications. This release is locally signed and is not Apple-notarized. Its DMG is a manual download; the Sparkle in-app feed still serves the previous signed release until the signing Mac publishes a new signed archive.

# StudyGuard 1.5.0 — Study Notebook

Introduces the Study Notebook sidebar, source imports, saved notes, cited Ollama chat, summaries, key points, quizzes, flashcards, JSON export, and timer restoration across app restarts. Version 1.5.1 additionally verifies local-model selection before submitting source material.

# StudyGuard 1.4.0 — Dark mode

- Adds Light, Dark, and System appearance choices in Settings.
- System follows your Mac’s current appearance, including scheduled changes.
- Saves your appearance choice across launches.
- Adds a charcoal palette with warm text, softer dividers, and brighter blue and rust accents.
- Applies the appearance to the timer, History, Settings, Distractions, daily goal, and Study Browser controls.
- Keeps focus history, goals, app/site lists, and the in-app updater.

From an installed copy of 1.3.0, finish your session, then choose Settings → Check for updates → Install and Relaunch. You can also download the DMG and drag StudyGuard into Applications using Finder. Quit older copies and launch the Applications copy.

Requires macOS 13 or newer on Apple silicon or Intel. The update archive is signed with StudyGuard’s update key. The app itself is locally signed and is not Apple-notarized. Both architectures are compiled; runtime appearance and the install/relaunch lifecycle have not been tested.

# StudyGuard 1.3.0

- Adds Sparkle-powered in-app download, installation, and relaunch from Settings → Check for updates.
- Adds Check for Updates to the StudyGuard application menu.
- Offers optional automatic checks; installation remains a user action.
- Verifies update archives with StudyGuard's Ed25519 signing key before extraction. Only the public key is included in source; the private key stays in the signing Mac's Keychain.
- Keeps the current app and settings until the new version is ready to install. Existing local goals, app/site lists, and history are retained.
- Disables manual update checks during an active session.
- Provides a pinned Sparkle dependency and a script to generate the signed GitHub-hosted update feed for future releases.

Install 1.3.0 once to enable this updater. Versions 1.2.0 and older can only open the GitHub download page. After this upgrade, future signed versions can install inside StudyGuard. Copy the app out of its DMG into Applications or another writable folder before updating.

Requires macOS 13 or newer on Apple silicon or Intel. This build is locally signed and is not notarized. Both architectures were compiled. The download/install/relaunch lifecycle has not been tested end to end.

# StudyGuard 1.2.0

- Implements the paper-and-ink Penpot design in the native SwiftUI app.
- Adds the bookmarked-page icon to the Dock, Finder, and sidebar.
- Bundles Libre Baskerville, IBM Plex Sans, and IBM Plex Mono with their licenses.
- Session screen has a large timer, Focus/Break switch, duration presets, study topic, and start/end button.
- Daily focus goal and totals appear alongside the timer; Edit goal opens a native sheet.
- History shows real local totals, the last seven days, and the eight most recent sessions.
- Distractions has scrollable app and domain lists with add/remove controls.
- Settings keeps the GitHub update check and download link.
- Study Browser adopts the same styling and shows the blocked-page message when a navigation is denied.
- Removing every blocked domain now stays saved after restarting.

Requires macOS 13 or newer on Apple silicon or Intel. Existing local history, selected apps, sites, and goals are retained. This build is locally signed and is not notarized.

Both architectures were compiled and the universal DMG was created. Runtime UI interactions were not tested in this request.

# StudyGuard 1.1.0

StudyGuard 1.1.0 adds a clearer study routine and a view of your progress.

- Give each focus session a topic, such as biology revision.
- Set a daily focus goal and see how close you are to it.
- Review a seven-day focus chart and your eight most recent sessions.
- Rest with a 5, 10, or 15 minute break timer. App and browser controls pause during breaks; Study Browser keeps its own site list.
- Goals, topics, and focus history are stored on your Mac. Existing focus totals are kept when you update.
- The GitHub update checker looks for StudyGuard releases in this repository.

Download the universal DMG, open it, and drag StudyGuard to Applications. Requires macOS 13 or newer on Apple silicon or Intel. This build is not Developer ID signed or notarized; the first launch may require Control-click → Open.

Session history begins with this version. Regular quits and Mac sleep save the current session. Unexpected crashes may leave the latest session out of the recent list, although focus time is saved while you study.
