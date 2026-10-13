import AppKit
import Combine
import SwiftUI
import WebKit

struct FocusApp: Codable, Identifiable, Hashable {
    var bundleID: String
    var name: String
    var id: String { bundleID }
}

@MainActor
final class FocusModel: ObservableObject {
    @Published var duration = 25
    @Published var secondsLeft = 25 * 60
    @Published var isRunning = false
    @Published var selectedApps: [FocusApp] = []
    @Published var blockedDomains: [String] = ["youtube.com", "instagram.com"]
    @Published var newDomain = ""
    @Published var activeTab = 0
    @Published var notice = "Pick a session length and choose what to keep out of reach."

    private var endDate: Date?
    private var ticker: AnyCancellable?
    private var lastQuitRequest: [String: Date] = [:]
    private var browserChecksInProgress = Set<String>()
    private let defaults = UserDefaults.standard

    init() {
        if let data = defaults.data(forKey: "selectedApps"),
           let saved = try? JSONDecoder().decode([FocusApp].self, from: data) {
            selectedApps = saved
        }
        let savedDomains = defaults.stringArray(forKey: "blockedDomains")
        if let savedDomains, !savedDomains.isEmpty { blockedDomains = savedDomains }
        refreshTicker()
    }

    var timeString: String {
        String(format: "%02d:%02d", max(0, secondsLeft) / 60, max(0, secondsLeft) % 60)
    }

    func setDuration(_ minutes: Int) {
        guard !isRunning else { return }
        duration = minutes
        secondsLeft = minutes * 60
    }

    func toggleSession() {
        if isRunning {
            endSession(message: "Session ended. Take a breath, then begin again when you’re ready.")
        } else {
            secondsLeft = duration * 60
            endDate = Date().addingTimeInterval(TimeInterval(secondsLeft))
            isRunning = true
            notice = "Focus session active. Selected apps and sites are being kept out of reach."
            refreshTicker()
            closeSelectedApps()
        }
    }

    func addApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an app to keep out of reach"
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
        ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, let endDate = self.endDate else { return }
            let remaining = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
            self.secondsLeft = remaining
            self.closeSelectedApps()
            if remaining == 0 {
                self.endSession(message: "Session complete. Nice work showing up for yourself.")
                NSSound(named: "Glass")?.play()
            }
        }
    }

    private func closeSelectedApps() {
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

    private func endSession(message: String) {
        isRunning = false
        endDate = nil
        ticker?.cancel()
        ticker = nil
        secondsLeft = duration * 60
        notice = message
    }
}

@main
struct StudyGuardApp: App {
    @StateObject private var model = FocusModel()
    var body: some Scene {
        WindowGroup {
            MainView(model: model)
                .frame(minWidth: 820, minHeight: 650)
                .preferredColorScheme(.light)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct MainView: View {
    @ObservedObject var model: FocusModel
    @State private var showBrowser = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    if model.activeTab == 0 { focusDashboard } else { browserDashboard }
                }
                .padding(34)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(red: 0.97, green: 0.965, blue: 0.945))
        }
        .background(Color(red: 0.97, green: 0.965, blue: 0.945))
        .sheet(isPresented: $showBrowser) { StudyBrowser(model: model).frame(minWidth: 760, minHeight: 560) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "sun.max.fill").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color(red: 0.91, green: 0.48, blue: 0.25))
                    .frame(width: 36, height: 36).background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                Text("STUDYGUARD").font(.system(size: 13, weight: .heavy, design: .rounded)).tracking(1.1)
            }.padding(.bottom, 26)
            sidebarItem("Focus", icon: "timer", index: 0)
            sidebarItem("Study Browser", icon: "safari", index: 1)
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "sparkle").foregroundStyle(Color(red: 0.91, green: 0.48, blue: 0.25))
                Text("One thing at a time.").font(.system(size: 13, weight: .semibold))
                Text("Small focused blocks add up.").font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(20).frame(width: 218).background(Color(red: 0.93, green: 0.92, blue: 0.885))
    }

    private func sidebarItem(_ title: String, icon: String, index: Int) -> some View {
        Button { model.activeTab = index } label: {
            HStack(spacing: 11) { Image(systemName: icon).frame(width: 20); Text(title); Spacer() }
                .font(.system(size: 13, weight: model.activeTab == index ? .semibold : .medium))
                .foregroundStyle(model.activeTab == index ? Color.black.opacity(0.85) : Color.black.opacity(0.54))
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(model.activeTab == index ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 11))
        }.buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.activeTab == 0 ? "Make room to focus." : "A quieter place to browse.")
                    .font(.system(size: 28, weight: .bold, design: .rounded)).tracking(-0.7)
                Text(model.activeTab == 0 ? "Protect a little time for what matters." : "Study online without the usual rabbit holes.")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
            }
            Spacer()
            if model.isRunning { Label("SESSION LIVE", systemImage: "circle.fill").font(.system(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(Color(red: 0.19, green: 0.51, blue: 0.38)).padding(.horizontal, 11).padding(.vertical, 8).background(Color(red: 0.86, green: 0.94, blue: 0.89), in: Capsule()) }
        }
    }

    private var focusDashboard: some View {
        VStack(alignment: .leading, spacing: 18) {
            timerCard
            HStack(alignment: .top, spacing: 18) { appCard; domainsCard }
            Text(model.notice).font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, -3)
            Text("Selected apps are managed while StudyGuard is open. Safari, Chrome, Edge, and Brave stay open; only tabs matching your blocked-site list are closed. Other browsers stay open if tab closing isn’t supported.")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var timerCard: some View {
        HStack(spacing: 30) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) { Image(systemName: "hourglass"); Text("YOUR FOCUS SESSION") }.font(.system(size: 10, weight: .bold)).tracking(1.0).foregroundStyle(.white.opacity(0.7))
                Text(model.timeString).font(.system(size: 64, weight: .medium, design: .rounded)).monospacedDigit().tracking(-2).foregroundStyle(.white)
                HStack(spacing: 9) {
                    ForEach([25, 50, 90], id: \.self) { minutes in
                        Button("\(minutes) min") { model.setDuration(minutes) }
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(model.duration == minutes ? Color.black : Color.white.opacity(0.75))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(model.duration == minutes ? Color.white : Color.white.opacity(0.13), in: Capsule())
                            .buttonStyle(.plain).disabled(model.isRunning)
                    }
                }
            }
            Spacer(minLength: 6)
            Button { model.toggleSession() } label: {
                VStack(spacing: 8) {
                    Image(systemName: model.isRunning ? "stop.fill" : "play.fill").font(.system(size: 18, weight: .bold))
                    Text(model.isRunning ? "End session" : "Start focusing").font(.system(size: 12, weight: .bold))
                }.foregroundStyle(Color(red: 0.15, green: 0.27, blue: 0.25)).frame(width: 124, height: 96)
                    .background(Color(red: 0.89, green: 0.91, blue: 0.73), in: RoundedRectangle(cornerRadius: 20))
            }.buttonStyle(.plain)
        }
        .padding(26).background(LinearGradient(colors: [Color(red: 0.17, green: 0.34, blue: 0.31), Color(red: 0.12, green: 0.25, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 23))
    }

    private var appCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle("Apps to pause", subtitle: "Close selected sites or pause selected apps", icon: "app.badge.checkmark")
            if model.selectedApps.isEmpty {
                Text("No apps selected yet.").font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 7)
            } else {
                ForEach(model.selectedApps) { app in
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID)?.path ?? "/Applications"))
                            .resizable().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 5))
                        Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Spacer(minLength: 2)
                        Button { model.removeApp(app) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }.buttonStyle(.plain)
                    }
                }
            }
            Button { model.addApplication() } label: { Label("Choose apps…", systemImage: "plus").font(.system(size: 11, weight: .semibold)) }
                .buttonStyle(.bordered).controlSize(.small)
            Divider()
            Text("Safari, Chrome, Edge, and Brave stay open; matching blocked-site tabs close. Unsupported browsers stay open. Other apps receive a graceful quit request so they can save work first.").font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(19).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private var domainsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle("Sites to avoid", subtitle: "Study Browser + selected browsers", icon: "globe")
            ForEach(model.blockedDomains, id: \.self) { domain in
                HStack { Image(systemName: "nosign").foregroundStyle(Color(red: 0.82, green: 0.39, blue: 0.25)); Text(domain).font(.system(size: 12, weight: .medium)); Spacer(); Button { model.removeDomain(domain) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }.buttonStyle(.plain) }
            }
            HStack(spacing: 7) {
                TextField("example.com", text: $model.newDomain).textFieldStyle(.roundedBorder).font(.system(size: 11))
                    .onSubmit { model.addDomain() }
                Button { model.addDomain() } label: { Image(systemName: "plus") }.buttonStyle(.bordered).controlSize(.small)
            }
            Divider()
            Button { showBrowser = true } label: { Label("Open Study Browser", systemImage: "safari").font(.system(size: 11, weight: .semibold)) }.buttonStyle(.bordered).controlSize(.small)
        }.padding(19).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func cardTitle(_ title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(red: 0.21, green: 0.43, blue: 0.37)).frame(width: 30, height: 30).background(Color(red: 0.9, green: 0.94, blue: 0.9), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 14, weight: .bold)); Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary) }
        }
    }

    private var browserDashboard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: "safari.fill").font(.system(size: 27)).foregroundStyle(Color(red: 0.21, green: 0.43, blue: 0.37))
                Text("Keep useful tabs. Skip the scroll.").font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Study Browser checks each page before it loads. Add domains on the Focus screen; blocked sites won’t open here.").font(.system(size: 13)).foregroundStyle(.secondary)
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 18))
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("CURRENT BLOCKLIST").font(.system(size: 10, weight: .bold)).tracking(0.7).foregroundStyle(.secondary)
                    ForEach(model.blockedDomains, id: \.self) { Text("•  \($0)").font(.system(size: 13, weight: .medium)) }
                    if model.blockedDomains.isEmpty { Text("No sites blocked").font(.system(size: 13)).foregroundStyle(.secondary) }
                }.padding(20).frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading).background(.white, in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR APPS").font(.system(size: 10, weight: .bold)).tracking(0.7).foregroundStyle(.secondary)
                    Text("Add Safari, Chrome, Edge, or Brave in Focus to close matching blocked-site tabs during a session. Unsupported browsers stay open. Other selected apps receive a graceful quit request.").font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button { model.activeTab = 0 } label: { Label("Configure focus", systemImage: "arrow.left").font(.system(size: 11, weight: .semibold)) }.buttonStyle(.bordered).controlSize(.small)
                }.padding(20).frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading).background(.white, in: RoundedRectangle(cornerRadius: 18))
            }
            Button { showBrowser = true } label: { Label("Open Study Browser", systemImage: "arrow.up.right.square").font(.system(size: 13, weight: .semibold)).padding(.vertical, 3) }.buttonStyle(.borderedProminent).tint(Color(red: 0.18, green: 0.37, blue: 0.33))
            Text("Study Browser is separate from Safari, Chrome, and other browsers. It does not replace or control them.").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

struct StudyBrowser: View {
    @ObservedObject var model: FocusModel
    @Environment(\.dismiss) private var dismiss
    @State private var address = "https://www.wikipedia.org"
    @State private var blockedPage = false
    @State private var webView = WKWebView()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { webView.goBack() } label: { Image(systemName: "chevron.left") }.disabled(!webView.canGoBack)
                Button { webView.goForward() } label: { Image(systemName: "chevron.right") }.disabled(!webView.canGoForward)
                TextField("Enter a website", text: $address).textFieldStyle(.roundedBorder).onSubmit(load)
                Button(action: load) { Image(systemName: "arrow.clockwise") }
                Button { dismiss() } label: { Image(systemName: "xmark") }.keyboardShortcut(.cancelAction)
            }.buttonStyle(.plain).padding(13).background(Color(red: 0.94, green: 0.94, blue: 0.92))
            if blockedPage {
                VStack(spacing: 12) { Image(systemName: "nosign").font(.system(size: 32)); Text("That site is on your focus list.").font(.system(size: 18, weight: .bold)); Text("It’s blocked in Study Browser while you keep this list.").font(.system(size: 13)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else { BrowserWebView(webView: webView, model: model) }
            HStack { Image(systemName: "lock.fill"); Text("Blocked here: \(model.blockedDomains.joined(separator: " · "))").lineLimit(1); Spacer(); Text("Study Browser").fontWeight(.semibold) }
                .font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 13).padding(.vertical, 9).background(Color(red: 0.94, green: 0.94, blue: 0.92))
        }.onAppear(perform: load)
    }

    private func load() {
        var value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.contains("://") { value = "https://" + value }
        guard let url = URL(string: value) else { return }
        if model.isBlocked(url) { blockedPage = true; return }
        blockedPage = false
        webView.load(URLRequest(url: url))
    }
}

struct BrowserWebView: NSViewRepresentable {
    let webView: WKWebView
    @ObservedObject var model: FocusModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeNSView(context: Context) -> WKWebView { webView.navigationDelegate = context.coordinator; return webView }
    func updateNSView(_ nsView: WKWebView, context: Context) { context.coordinator.model = model }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var model: FocusModel
        init(model: FocusModel) { self.model = model }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
            decisionHandler(model.isBlocked(url) ? .cancel : .allow)
        }
    }
}
