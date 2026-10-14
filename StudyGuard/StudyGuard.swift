import AppKit
import Combine
import SwiftUI
import WebKit

struct FocusApp: Codable, Identifiable, Hashable {
    var bundleID: String
    var name: String
    var id: String { bundleID }
}

struct StudySession: Codable, Identifiable {
    var id = UUID()
    var startedAt: Date
    var subject: String
    var seconds: Int
    var completed: Bool
}

struct StudyDay: Identifiable {
    var date: Date
    var seconds: Int
    var id: Date { date }
}

@MainActor
final class FocusModel: ObservableObject {
    @Published var duration = 25
    @Published var secondsLeft = 25 * 60
    @Published var isRunning = false
    @Published var isBreak = false
    @Published var breakDuration = 5
    @Published var subject = "" {
        didSet { defaults.set(subject, forKey: "studySubject") }
    }
    @Published var dailyGoalMinutes = 60 {
        didSet { defaults.set(dailyGoalMinutes, forKey: "dailyGoalMinutes") }
    }
    @Published var history: [StudySession] = []
    @Published var selectedApps: [FocusApp] = []
    @Published var blockedDomains: [String] = ["youtube.com", "instagram.com"]
    @Published var newDomain = ""
    @Published var activeTab = 0
    @Published var notice = "Choose a duration, then start your session."
    @Published var totalFocusSeconds: Int
    @Published var todayFocusSeconds: Int
    @Published var sessionsStarted: Int
    @Published var updateMessage = "Not checked yet."
    @Published var updateAvailable = false
    @Published var isCheckingForUpdates = false

    private var endDate: Date?
    private var sessionStartedAt: Date?
    private var accountedThrough: Date?
    private var sessionSeconds = 0
    private var ticker: AnyCancellable?
    private var lifecycleObservers: [AnyCancellable] = []
    private var lastQuitRequest: [String: Date] = [:]
    private var browserChecksInProgress = Set<String>()
    private let defaults = UserDefaults.standard
    private let statsDateKey = "focusSecondsByDay"
    private var recordedToday: [String: Int]

    init() {
        recordedToday = defaults.dictionary(forKey: statsDateKey) as? [String: Int] ?? [:]
        totalFocusSeconds = recordedToday.values.reduce(0, +)
        todayFocusSeconds = recordedToday[Self.dayKey(for: Date())] ?? 0
        sessionsStarted = defaults.integer(forKey: "completedFocusSessions")
        subject = defaults.string(forKey: "studySubject") ?? ""
        let savedGoal = defaults.integer(forKey: "dailyGoalMinutes")
        dailyGoalMinutes = savedGoal == 0 ? 60 : min(360, max(15, savedGoal))
        if let data = defaults.data(forKey: "studySessionHistory"),
           let saved = try? JSONDecoder().decode([StudySession].self, from: data) {
            history = saved
        }
        if let data = defaults.data(forKey: "selectedApps"),
           let saved = try? JSONDecoder().decode([FocusApp].self, from: data) {
            selectedApps = saved
        }
        let savedDomains = defaults.stringArray(forKey: "blockedDomains")
        if let savedDomains { blockedDomains = savedDomains }
        refreshTicker()
        lifecycleObservers.append(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification).sink { [weak self] _ in
            self?.finishBeforeClosing()
        })
        lifecycleObservers.append(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification).sink { [weak self] _ in
            self?.finishBeforeClosing()
        })
        lifecycleObservers.append(Timer.publish(every: 60, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.refreshCalendarDay()
        })
    }

    var weeklyDays: [StudyDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-6...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return StudyDay(date: date, seconds: recordedToday[Self.dayKey(for: date)] ?? 0)
        }
    }

    var goalProgress: Double {
        min(1, Double(todayFocusSeconds) / Double(dailyGoalMinutes * 60))
    }

    private func refreshCalendarDay() {
        todayFocusSeconds = recordedToday[Self.dayKey(for: Date())] ?? 0
    }

    func selectMode(isBreak: Bool) {
        guard !isRunning else { return }
        self.isBreak = isBreak
        secondsLeft = (isBreak ? breakDuration : duration) * 60
    }

    var timeString: String {
        String(format: "%02d:%02d", max(0, secondsLeft) / 60, max(0, secondsLeft) % 60)
    }

    func setDuration(_ minutes: Int) {
        guard !isRunning else { return }
        if isBreak { breakDuration = minutes } else { duration = minutes }
        secondsLeft = minutes * 60
    }

    func toggleSession() {
        if isRunning {
            endSession(message: isBreak ? "Break ended." : "Session ended.")
        } else {
            refreshCalendarDay()
            secondsLeft = (isBreak ? breakDuration : duration) * 60
            sessionStartedAt = Date()
            accountedThrough = sessionStartedAt
            sessionSeconds = 0
            endDate = Date().addingTimeInterval(TimeInterval(secondsLeft))
            isRunning = true
            if !isBreak {
                sessionsStarted += 1
                defaults.set(sessionsStarted, forKey: "completedFocusSessions")
            }
            notice = isBreak ? "Break active. App and tab controls are paused." : "Focus session active. Selected app and tab controls are enabled."
            refreshTicker()
            closeSelectedApps()
        }
    }

    func addApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose apps to restrict during focus"
        panel.prompt = "Add App"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { continue }
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            if !selectedApps.contains(where: { $0.bundleID == id }) {
                selectedApps.append(FocusApp(bundleID: id, name: name))
            }
        }
        saveApps()
        if isRunning { closeSelectedApps() }
    }

    func removeApp(_ app: FocusApp) {
        selectedApps.removeAll { $0.id == app.id }
        saveApps()
    }

    func addDomain() {
        let clean = newDomain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .split(separator: "/").first.map(String.init) ?? ""
        guard !clean.isEmpty, clean.contains("."), !blockedDomains.contains(clean) else { return }
        blockedDomains.append(clean)
        defaults.set(blockedDomains, forKey: "blockedDomains")
        newDomain = ""
    }

    func removeDomain(_ domain: String) {
        blockedDomains.removeAll { $0 == domain }
        defaults.set(blockedDomains, forKey: "blockedDomains")
    }

    func isBlocked(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return blockedDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private func saveApps() {
        if let data = try? JSONEncoder().encode(selectedApps) { defaults.set(data, forKey: "selectedApps") }
    }

    private func refreshTicker() {
        ticker?.cancel()
        guard isRunning else { return }
        ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, let endDate = self.endDate else { return }
            self.recordFocusTime()
            let remaining = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
            self.secondsLeft = remaining
            self.closeSelectedApps()
            if remaining == 0 {
                self.endSession(message: self.isBreak ? "Break complete." : "Session complete.", completed: true)
                NSSound(named: "Glass")?.play()
            }
        }
    }

    private func recordFocusTime() {
        guard isRunning, !isBreak, var cursor = accountedThrough, let endDate else { return }
        let elapsed = max(0, Int(min(Date(), endDate).timeIntervalSince(cursor)))
        guard elapsed > 0 else { return }
        let target = cursor.addingTimeInterval(TimeInterval(elapsed))
        let origin = cursor
        while cursor < target {
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: cursor)) ?? target
            let segmentEnd = min(target, dayEnd)
            let seconds = Int(segmentEnd.timeIntervalSince(origin)) - Int(cursor.timeIntervalSince(origin))
            recordedToday[Self.dayKey(for: cursor), default: 0] += seconds
            cursor = segmentEnd
        }
        accountedThrough = target
        totalFocusSeconds += elapsed
        sessionSeconds += elapsed
        todayFocusSeconds = recordedToday[Self.dayKey(for: Date())] ?? 0
        defaults.set(recordedToday, forKey: statsDateKey)
    }

    private func finishBeforeClosing() {
        guard isRunning else { return }
        endSession(message: "Session saved.")
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        updateAvailable = false
        updateMessage = "Checking GitHub for updates…"
        let url = URL(string: "https://api.github.com/repos/Sumi1124/Focus/releases?per_page=100")!
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("StudyGuard macOS updater", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isCheckingForUpdates = false
                guard error == nil, let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let data, let releases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let release = releases.first(where: {
                          ($0["tag_name"] as? String)?.hasPrefix("studyguard-v") == true && ($0["prerelease"] as? Bool) != true && ($0["draft"] as? Bool) != true
                      }),
                      let tag = release["tag_name"] as? String,
                      let htmlURL = release["html_url"] as? String,
                      let pageURL = URL(string: htmlURL) else {
                    self.updateMessage = "Couldn’t check GitHub. Check your internet connection and try again."
                    return
                }
                let latest = String(tag.dropFirst("studyguard-v".count))
                let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
                if Self.version(latest, isNewerThan: current) {
                    self.updateAvailable = true
                    self.updateMessage = "StudyGuard \(latest) is available. Open the release to download and install it."
                    self.defaults.set(pageURL.absoluteString, forKey: "studyGuardLatestReleaseURL")
                } else {
                    self.updateMessage = "You’re up to date (version \(current))."
                }
            }
        }.resume()
    }

    func openLatestRelease() {
        guard let value = defaults.string(forKey: "studyGuardLatestReleaseURL"), let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func version(_ candidate: String, isNewerThan current: String) -> Bool {
        let lhs = candidate.split(separator: ".").compactMap { Int($0) }
        let rhs = current.split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private func closeSelectedApps() {
        guard isRunning, !isBreak else { return }
        let browserNames = [
            "com.apple.Safari": "Safari",
            "com.google.Chrome": "Google Chrome",
            "com.microsoft.edgemac": "Microsoft Edge",
            "com.brave.Browser": "Brave Browser"
        ]
        let browserMarkers = ["safari", "chrome", "chromium", "edge", "brave", "firefox", "arc", "opera", "vivaldi", "orion", "browser"]
        for selected in selectedApps {
            if let browserName = browserNames[selected.bundleID] {
                closeBlockedTabs(in: selected, appleScriptName: browserName)
                continue
            }
            let appIdentity = (selected.name + " " + selected.bundleID).lowercased()
            if browserMarkers.contains(where: appIdentity.contains) {
                notice = "\(selected.name) stays open. Tab closing currently supports Safari, Chrome, Edge, and Brave."
                continue
            }
            for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == selected.bundleID {
                guard let id = app.bundleIdentifier else { continue }
                if let lastRequest = lastQuitRequest[id], Date().timeIntervalSince(lastRequest) < 15 { continue }
                lastQuitRequest[id] = Date()
                app.terminate() // Graceful request; the user can cancel if the app has unsaved work.
            }
        }
    }

    private func closeBlockedTabs(in app: FocusApp, appleScriptName: String) {
        guard NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == app.bundleID }),
              !blockedDomains.isEmpty,
              browserChecksInProgress.insert(app.bundleID).inserted else { return }
        let now = Date()
        if let lastRequest = lastQuitRequest[app.bundleID], now.timeIntervalSince(lastRequest) < 3 {
            browserChecksInProgress.remove(app.bundleID)
            return
        }
        lastQuitRequest[app.bundleID] = now
        let hosts = blockedDomains.map {
            "\"\($0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
        }.joined(separator: ", ")
        let scriptSource = """
        set blockedHosts to {\(hosts)}
        tell application "\(appleScriptName)"
            repeat with winRef in windows
                repeat with tabRef in tabs of winRef
                    try
                        set tabURL to URL of tabRef
                        repeat with hostRef in blockedHosts
                            if tabURL contains (hostRef as text) then
                                close tabRef
                                exit repeat
                            end if
                        end repeat
                    end try
                end repeat
            end repeat
        end tell
        """
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var error: NSDictionary?
            NSAppleScript(source: scriptSource)?.executeAndReturnError(&error)
            DispatchQueue.main.async {
                self?.browserChecksInProgress.remove(app.bundleID)
                if error != nil {
                    self?.notice = "Allow StudyGuard to control \(appleScriptName) in System Settings → Privacy & Security → Automation."
                }
            }
        }
    }

    private func endSession(message: String, completed: Bool = false) {
        recordFocusTime()
        if !isBreak, sessionSeconds > 0, let startedAt = sessionStartedAt {
            let title = subject.trimmingCharacters(in: .whitespacesAndNewlines)
            history.insert(StudySession(startedAt: startedAt, subject: title.isEmpty ? "Focus session" : title, seconds: sessionSeconds, completed: completed), at: 0)
            history = Array(history.prefix(100))
            if let data = try? JSONEncoder().encode(history) { defaults.set(data, forKey: "studySessionHistory") }
        }
        isRunning = false
        endDate = nil
        sessionStartedAt = nil
        accountedThrough = nil
        sessionSeconds = 0
        ticker?.cancel()
        ticker = nil
        secondsLeft = (isBreak ? breakDuration : duration) * 60
        notice = message
    }
}
