import AppKit
import CoreText
import SwiftUI
import WebKit

enum Ink {
    static let paper = Color(hex: 0xFAF8F3)
    static let rail = Color(hex: 0xF0ECE3)
    static let text = Color(hex: 0x27262B)
    static let muted = Color(hex: 0x77736C)
    static let line = Color(hex: 0xDCD7CC)
    static let blue = Color(hex: 0x3E4E9B)
    static let rust = Color(hex: 0xC56B3B)
    static let selected = Color(hex: 0xE7E9F2)
    static func sans(_ size: CGFloat = 14, _ weight: Font.Weight = .regular) -> Font {
        .custom("IBMPlexSans-Regular", size: size).weight(weight)
    }
    static func mono(_ size: CGFloat = 12) -> Font { .custom("IBMPlexMono-Regular", size: size) }
    static func title(_ size: CGFloat = 32) -> Font { .custom("LibreBaskerville-Regular", size: size) }
    static func registerFonts() {
        guard let folder = Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
              let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for url in urls where url.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
    static var icon: NSImage {
        if let url = Bundle.main.url(forResource: "StudyGuard-1024", withExtension: "png"),
           let image = NSImage(contentsOf: url) { return image }
        return NSApplication.shared.applicationIconImage
    }
    static func duration(_ seconds: Int, precise: Bool = false) -> String {
        if precise && seconds < 60 { return "\(seconds)s" }
        if seconds >= 3600 { return "\(seconds / 3600)h \((seconds % 3600) / 60)m" }
        return "\(seconds / 60) min"
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

struct InkRule: View {
    var body: some View { Rectangle().fill(Ink.line).frame(height: 1).accessibilityHidden(true) }
}

struct InkButtonStyle: ButtonStyle {
    var primary = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(Ink.sans(14, .medium))
            .foregroundStyle(primary ? Color.white : Ink.text)
            .padding(.horizontal, 16).frame(minHeight: 40)
            .background(primary ? Ink.blue : Ink.rail, in: RoundedRectangle(cornerRadius: 5))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct InkLink: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(title, action: action).buttonStyle(.plain)
            .font(Ink.sans(13, .medium)).foregroundStyle(Ink.blue)
    }
}

@main
struct StudyGuardApp: App {
    @StateObject private var model = FocusModel()
    @StateObject private var updater = AppUpdater()
    init() { Ink.registerFonts() }
    var body: some Scene {
        WindowGroup {
            MainView(model: model, updater: updater).frame(minWidth: 1000, minHeight: 740)
                .preferredColorScheme(.light)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1152, height: 800)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates || model.isRunning)
            }
        }
    }
}

struct MainView: View {
    @ObservedObject var model: FocusModel
    @ObservedObject var updater: AppUpdater
    @State private var showBrowser = false
    @State private var showSettings = false
    @State private var showDistractions = false
    @State private var showGoal = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if model.activeTab == 0 { session }
                    else if model.activeTab == 2 { history }
                    else { browser }
                }.padding(.horizontal, 48).padding(.top, 44).padding(.bottom, 24)
                    .frame(maxWidth: 1120, alignment: .leading).frame(maxWidth: .infinity)
            }.background(Ink.paper)
        }
        .font(Ink.sans()).foregroundStyle(Ink.text).background(Ink.paper)
        .ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $showSettings) { SettingsView(model: model, updater: updater) }
        .sheet(isPresented: $showDistractions) { DistractionsView(model: model) }
        .sheet(isPresented: $showGoal) { GoalView(model: model) }
        .sheet(isPresented: $showBrowser) { StudyBrowser(model: model).frame(minWidth: 800, minHeight: 600) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: Ink.icon).resizable().frame(width: 36, height: 36).accessibilityHidden(true)
                Text("StudyGuard").font(Ink.sans(16, .semibold))
            }.padding(.horizontal, 18).padding(.top, 66).padding(.bottom, 67)
            navigation("Session", number: "01", index: 0)
            navigation("History", number: "02", index: 2)
            navigation("Study Browser", number: "03", index: 1)
            Spacer(minLength: 100)
            VStack(alignment: .leading, spacing: 16) {
                InkRule()
                Text("History stays on this Mac.").font(Ink.sans(11)).foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Settings") { showSettings = true }.buttonStyle(.plain).font(Ink.sans())
                    .padding(.top, 46).padding(.bottom, 36)
            }.padding(.horizontal, 22)
        }.frame(width: 184).background(Ink.rail)
            .overlay(alignment: .trailing) { Rectangle().fill(Ink.line).frame(width: 1) }
    }

    private func navigation(_ name: String, number: String, index: Int) -> some View {
        Button { model.activeTab = index } label: {
            HStack(spacing: 10) {
                Text(number).font(Ink.mono(11)).foregroundStyle(model.activeTab == index ? Ink.blue : Ink.muted)
                    .frame(width: 25, alignment: .leading)
                Text(name).font(Ink.sans(14, model.activeTab == index ? .semibold : .regular))
                    .foregroundStyle(model.activeTab == index ? Ink.text : Ink.muted)
                Spacer(minLength: 0)
            }.padding(.horizontal, 22).frame(height: 47)
                .contentShape(Rectangle())
                .overlay(alignment: .leading) {
                    if model.activeTab == index { Rectangle().fill(Ink.blue).frame(width: 3, height: 36) }
                }
        }.buttonStyle(.plain).accessibilityAddTraits(model.activeTab == index ? .isSelected : [])
    }

    private var header: some View {
        let title = model.activeTab == 0 ? (model.isBreak ? "Break" : "Focus") : model.activeTab == 2 ? "History" : "Study Browser"
        let section = model.activeTab == 0 ? "SESSION" : model.activeTab == 2 ? "HISTORY" : "BROWSER"
        let subtitle = model.activeTab == 0 ? "Set a timer. Choose what to block." : model.activeTab == 2 ? "Focus time and recent sessions." : "Browse with your blocked-site list enabled."
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("STUDYGUARD / \(section)")
                Spacer()
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased())
            }.font(Ink.mono(11)).foregroundStyle(Ink.muted)
            Text(title).font(Ink.title()).padding(.top, 26)
            Text(subtitle).font(Ink.sans()).foregroundStyle(Ink.muted).padding(.top, 14)
            InkRule().padding(.top, 28).padding(.bottom, 28)
        }
    }

    private var session: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 38) {
                timer.frame(maxWidth: .infinity)
                Rectangle().fill(Ink.line).frame(width: 1, height: 465).accessibilityHidden(true)
                totals.frame(width: 224, alignment: .leading)
            }
            InkRule().padding(.top, 34)
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(model.isBreak ? "Controls paused during breaks" : "Blocking during focus")
                    .font(Ink.sans(13, .medium))
                Text(distractionSummary).font(Ink.sans(13)).foregroundStyle(Ink.muted)
                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                InkLink(title: "Edit →") { showDistractions = true }.accessibilityLabel("Edit distractions")
            }.padding(.top, 20)
            Text(model.notice).font(Ink.sans(12)).foregroundStyle(Ink.muted)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 18)
        }
    }

    private var distractionSummary: String {
        let items = model.selectedApps.map(\.name) + model.blockedDomains
        return items.isEmpty ? "No apps or sites selected" : items.joined(separator: " · ")
    }

    private var timer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 40) {
                modeButton("Focus", isBreak: false)
                modeButton("Break", isBreak: true)
                Spacer()
                Text(model.isRunning ? "RUNNING" : "READY").font(Ink.mono(11)).foregroundStyle(Ink.muted).padding(.top, 4)
            }
            Text(model.timeString).font(Ink.mono(112)).foregroundStyle(Ink.text)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 145, alignment: .leading)
                .padding(.top, 28).accessibilityLabel("Time remaining: \(model.timeString)")
            timeScale.padding(.top, 24)
            HStack(spacing: 12) {
                ForEach(model.isBreak ? [5, 10, 15] : [25, 50, 90], id: \.self) { minutes in
                    let selected = (model.isBreak ? model.breakDuration : model.duration) == minutes
                    Button("\(minutes) min") { model.setDuration(minutes) }
                        .buttonStyle(.plain).font(Ink.sans(14, .medium))
                        .foregroundStyle(selected ? Ink.blue : Ink.muted)
                        .frame(width: 85, height: 34)
                        .background(selected ? Ink.selected : .clear, in: RoundedRectangle(cornerRadius: 4))
                        .disabled(model.isRunning).accessibilityAddTraits(selected ? .isSelected : [])
                }
            }.padding(.top, 26)
            if model.isBreak {
                Text("On a break").font(Ink.sans(12, .medium)).foregroundStyle(Ink.muted).padding(.top, 30)
                Text("App and tab controls pause. Study Browser keeps its site list.")
                    .font(Ink.sans(14)).foregroundStyle(Ink.muted)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.top, 10)
            } else {
                Text("Working on").font(Ink.sans(12, .medium)).foregroundStyle(Ink.muted).padding(.top, 30)
                TextField("Study topic", text: $model.subject).textFieldStyle(.plain).font(Ink.sans(15))
                    .padding(.horizontal, 14).frame(height: 44).background(.white, in: RoundedRectangle(cornerRadius: 4))
                    .disabled(model.isRunning).padding(.top, 10)
                    .onChange(of: model.subject) { value in
                        if value.count > 100 { model.subject = String(value.prefix(100)) }
                    }
            }
            Button { model.toggleSession() } label: {
                Text(model.isRunning ? (model.isBreak ? "End break" : "End session") : (model.isBreak ? "Start break" : "Start session"))
                    .frame(maxWidth: .infinity, minHeight: 6)
            }.buttonStyle(InkButtonStyle()).padding(.top, 18)
        }
    }

    private func modeButton(_ title: String, isBreak: Bool) -> some View {
        Button { model.selectMode(isBreak: isBreak) } label: {
            VStack(alignment: .leading, spacing: 20) {
                Text(title).font(Ink.sans(14, model.isBreak == isBreak ? .semibold : .regular))
                    .foregroundStyle(model.isBreak == isBreak ? Ink.blue : Ink.muted)
                Rectangle().fill(model.isBreak == isBreak ? Ink.blue : .clear).frame(width: 45, height: 2)
            }
        }.buttonStyle(.plain).disabled(model.isRunning)
            .accessibilityAddTraits(model.isBreak == isBreak ? .isSelected : [])
    }

    private var timeScale: some View {
        let length = Double((model.isBreak ? model.breakDuration : model.duration) * 60)
        let elapsed = min(1, max(0, 1 - Double(model.secondsLeft) / length))
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                InkRule()
                HStack(spacing: 0) {
                    ForEach(0..<13) { index in
                        Rectangle().fill(Ink.line).frame(width: 1, height: 9)
                        if index < 12 { Spacer(minLength: 0) }
                    }
                }
                Rectangle().fill(Ink.rust).frame(width: 4, height: 13)
                    .offset(x: max(0, (geometry.size.width - 4) * elapsed))
            }.frame(height: 13)
        }.frame(height: 13).accessibilityHidden(true)
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TODAY").font(Ink.mono(11)).foregroundStyle(Ink.muted)
            Text("\(model.todayFocusSeconds / 60)").font(Ink.mono(56)).padding(.top, 24)
            Text("of \(model.dailyGoalMinutes) minutes").foregroundStyle(Ink.muted).padding(.top, 4)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Ink.line)
                    Rectangle().fill(Ink.rust).frame(width: geometry.size.width * model.goalProgress)
                }
            }.frame(height: 3).padding(.top, 26)
                .accessibilityLabel("Daily goal \(Int(model.goalProgress * 100)) percent complete")
            InkLink(title: "Edit goal →") { showGoal = true }.padding(.top, 18)
            InkRule().padding(.top, 38)
            Text("Total focus").font(Ink.sans(13)).foregroundStyle(Ink.muted).padding(.top, 22)
            Text(Ink.duration(model.totalFocusSeconds)).font(Ink.mono(24)).padding(.top, 15)
            Text("Sessions started").font(Ink.sans(13)).foregroundStyle(Ink.muted).padding(.top, 36)
            Text("\(model.sessionsStarted)").font(Ink.mono(24)).padding(.top, 15)
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 24) {
                statistic("Today", value: Ink.duration(model.todayFocusSeconds))
                Rectangle().fill(Ink.line).frame(width: 1, height: 80)
                statistic("Total focus", value: Ink.duration(model.totalFocusSeconds))
                Rectangle().fill(Ink.line).frame(width: 1, height: 80)
                statistic("Sessions started", value: "\(model.sessionsStarted)")
            }
            InkRule().padding(.top, 30)
            weeklyChart.padding(.top, 22)
            InkRule().padding(.top, 28)
            HStack {
                Text("Recent sessions").font(Ink.sans(16, .medium))
                Spacer()
                Text("LAST 8").font(Ink.mono(10)).foregroundStyle(Ink.muted)
            }.padding(.top, 20).padding(.bottom, 16)
            if model.history.isEmpty {
                Text("No sessions yet. Your next focus session will appear here.")
                    .foregroundStyle(Ink.muted).padding(.vertical, 24)
            } else {
                ForEach(Array(model.history.prefix(8))) { item in
                    HStack(spacing: 18) {
                        Text(item.subject).font(Ink.sans()).lineLimit(1).help(item.subject)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(Ink.sans(12)).foregroundStyle(Ink.muted).frame(width: 155, alignment: .leading)
                        Text(Ink.duration(item.seconds, precise: true)).font(Ink.mono(13)).frame(width: 90, alignment: .leading)
                        Text(item.completed ? "Completed" : "Ended early").font(Ink.sans(12))
                            .foregroundStyle(item.completed ? Ink.blue : Ink.muted).frame(width: 105, alignment: .leading)
                    }.padding(.vertical, 13)
                    InkRule()
                }
            }
        }
    }

    private func statistic(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title).font(Ink.sans(13)).foregroundStyle(Ink.muted)
            Text(value).font(Ink.mono(32)).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weeklyChart: some View {
        let days = model.weeklyDays
        let maximum = max(3600, days.map(\.seconds).max() ?? 0)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Last 7 days").font(Ink.sans(16, .medium))
                Spacer()
                Text("\(Ink.duration(days.reduce(0) { $0 + $1.seconds })) total").font(Ink.mono(13)).foregroundStyle(Ink.muted)
            }.padding(.bottom, 28)
            HStack(alignment: .bottom, spacing: 24) {
                ForEach(days) { day in
                    let today = Calendar.current.isDateInToday(day.date)
                    VStack(spacing: 10) {
                        Spacer(minLength: 0)
                        Text("\(day.seconds / 60)m").font(Ink.mono(11)).foregroundStyle(Ink.muted)
                        Rectangle().fill(today ? Ink.rust : Ink.blue)
                            .frame(width: 58, height: day.seconds == 0 ? 0 : max(3, 100 * Double(day.seconds) / Double(maximum)))
                    }.frame(maxWidth: .infinity).frame(height: 130)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted)): \(day.seconds / 60) focus minutes")
                }
            }
            InkRule()
            HStack(spacing: 24) {
                ForEach(days) { day in
                    Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(Ink.sans(12, Calendar.current.isDateInToday(day.date) ? .medium : .regular))
                        .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Ink.text : Ink.muted)
                        .frame(maxWidth: .infinity)
                }
            }.padding(.top, 14)
        }
    }

    private var browser: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Browser").font(Ink.sans(19, .medium))
                    Text("Opens in a separate study window.").foregroundStyle(Ink.muted).padding(.top, 16)
                    browserPreview.padding(.top, 36)
                    Button("Open browser ↗") { showBrowser = true }.buttonStyle(InkButtonStyle()).padding(.top, 28)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(Ink.line).frame(width: 1, height: 465)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Blocked sites").font(Ink.sans(19, .medium))
                    Text("Used in Study Browser and selected browsers.").font(Ink.sans(13)).foregroundStyle(Ink.muted)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 16).padding(.bottom, 28)
                    if model.blockedDomains.isEmpty { Text("No sites selected").foregroundStyle(Ink.muted).padding(.vertical, 20) }
                    ForEach(model.blockedDomains, id: \.self) { domain in
                        InkRule()
                        Text(domain).font(Ink.mono(14)).lineLimit(2).padding(.vertical, 18)
                    }
                    InkRule()
                    InkLink(title: "Edit list →") { showDistractions = true }.padding(.top, 20)
                }.frame(width: 240, alignment: .leading)
            }
            InkRule().padding(.top, 36)
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                Text("Safari, Chrome, Edge & Brave").font(Ink.sans(13, .medium))
                Text("Only blocked tabs close during focus.").font(Ink.sans(13)).foregroundStyle(Ink.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                InkLink(title: "Edit →") { showDistractions = true }.accessibilityLabel("Edit selected browsers")
            }.padding(.top, 20)
        }
    }

    private var browserPreview: some View {
        let site = model.blockedDomains.first
        return VStack(spacing: 0) {
            Text(site.map { "https://\($0)" } ?? "https://www.wikipedia.org")
                .font(Ink.mono(12)).foregroundStyle(Ink.muted).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Ink.rail)
            VStack(spacing: 20) {
                Spacer()
                Text(site == nil ? "Ready to browse" : "This site is blocked").font(Ink.title(24))
                Text(site.map { "\($0) is on your block list." } ?? "Add sites to restrict in Edit list.")
                    .font(Ink.sans()).foregroundStyle(Ink.muted).multilineTextAlignment(.center)
                Spacer()
                Text("BROWSER PREVIEW").font(Ink.mono(10)).foregroundStyle(Ink.muted).padding(.bottom, 32)
            }.padding(.horizontal, 24).frame(height: 248).frame(maxWidth: .infinity).background(.white)
        }.clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

struct SheetHeading: View {
    let title: String
    let close: () -> Void
    var body: some View {
        HStack(alignment: .top) {
            Text(title).font(Ink.title(28))
            Spacer()
            Button(action: close) { Image(systemName: "xmark").font(.system(size: 13)).foregroundStyle(Ink.muted) }
                .buttonStyle(.plain).padding(8).accessibilityLabel("Close \(title)")
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: FocusModel
    @ObservedObject var updater: AppUpdater
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeading(title: "Settings") { dismiss() }
            Text("StudyGuard \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.0")")
                .font(Ink.mono(12)).foregroundStyle(Ink.muted).padding(.top, 18)
            InkRule().padding(.vertical, 25)
            Text("Updates").font(Ink.sans(16, .medium))
            Text("Download and install new versions inside StudyGuard.")
                .foregroundStyle(Ink.muted).padding(.top, 14)
            HStack(spacing: 16) {
                Button { dismiss(); updater.checkForUpdates() } label: { Text("Check for updates") }
                    .buttonStyle(InkButtonStyle()).disabled(!updater.canCheckForUpdates || model.isRunning)
            }.padding(.top, 20)
            Text(model.isRunning ? "Finish your session before updating." : updater.status)
                .font(Ink.sans(12)).foregroundStyle(Ink.muted)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 14)
            Toggle("Check for updates automatically", isOn: Binding(
                get: { updater.automaticChecks }, set: { updater.setAutomaticChecks($0) }
            )).toggleStyle(.checkbox).font(Ink.sans(13)).padding(.top, 18)
            Text("Install and Relaunch replaces this app. Your history and settings stay on this Mac.")
                .font(Ink.sans(12)).foregroundStyle(Ink.muted).padding(.top, 14)
            InkRule().padding(.vertical, 24)
            Text("Goals and history are stored on this Mac.").font(Ink.sans(13)).foregroundStyle(Ink.muted)
            Spacer(minLength: 20)
            HStack { Spacer(); Button("Done") { dismiss() }.buttonStyle(InkButtonStyle()).keyboardShortcut(.cancelAction) }
        }.padding(28).frame(width: 560, height: 500).font(Ink.sans()).foregroundStyle(Ink.text).background(Ink.paper)
    }
}

struct DistractionsView: View {
    @ObservedObject var model: FocusModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeading(title: "Distractions") { dismiss() }
            Text("Choose apps and sites to restrict during a session.").foregroundStyle(Ink.muted).padding(.top, 14)
            InkRule().padding(.vertical, 24)
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Apps").font(Ink.sans(18, .medium))
                    Text("Supported browsers close blocked tabs.").font(Ink.sans(12)).foregroundStyle(Ink.muted)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if model.selectedApps.isEmpty { Text("No apps selected").foregroundStyle(Ink.muted).padding(.vertical, 18) }
                            ForEach(model.selectedApps) { app in
                                InkRule()
                                HStack {
                                    Text(app.name).lineLimit(1).help(app.name)
                                    Spacer()
                                    removeButton("Remove \(app.name)") { model.removeApp(app) }
                                }.padding(.vertical, 15)
                            }
                            InkRule()
                        }
                    }.frame(height: 148)
                    Button("+ Choose apps…") { model.addApplication() }.buttonStyle(InkButtonStyle(primary: false))
                    Text("Other selected apps receive a quit request. Unsupported browsers stay open.")
                        .font(Ink.sans(12)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(Ink.line).frame(width: 1, height: 310)
                VStack(alignment: .leading, spacing: 18) {
                    Text("Sites").font(Ink.sans(18, .medium))
                    Text("Domains and their subdomains.").font(Ink.sans(12)).foregroundStyle(Ink.muted)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if model.blockedDomains.isEmpty { Text("No sites selected").foregroundStyle(Ink.muted).padding(.vertical, 18) }
                            ForEach(model.blockedDomains, id: \.self) { domain in
                                InkRule()
                                HStack {
                                    Text(domain).font(Ink.mono(13)).lineLimit(1).help(domain)
                                    Spacer()
                                    removeButton("Remove \(domain)") { model.removeDomain(domain) }
                                }.padding(.vertical, 15)
                            }
                            InkRule()
                        }
                    }.frame(height: 148)
                    HStack(spacing: 10) {
                        TextField("example.com", text: $model.newDomain).textFieldStyle(.plain).font(Ink.mono(13))
                            .padding(.horizontal, 12).frame(height: 40).background(.white, in: RoundedRectangle(cornerRadius: 4))
                            .onSubmit { model.addDomain() }
                        Button { model.addDomain() } label: { Text("+") }
                            .buttonStyle(InkButtonStyle()).accessibilityLabel("Add blocked domain")
                            .disabled(model.newDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text("Study Browser always uses this list.").font(Ink.sans(12)).foregroundStyle(Ink.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 20)
            InkRule().padding(.bottom, 20)
            HStack { Spacer(); Button("Done") { dismiss() }.buttonStyle(InkButtonStyle()).keyboardShortcut(.cancelAction) }
        }.padding(28).frame(width: 700, height: 550).font(Ink.sans()).foregroundStyle(Ink.text).background(Ink.paper)
    }
    private func removeButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(Ink.muted).padding(6) }
            .buttonStyle(.plain).accessibilityLabel(name)
    }
}

struct GoalView: View {
    @ObservedObject var model: FocusModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SheetHeading(title: "Daily goal") { dismiss() }
            InkRule()
            Stepper(value: $model.dailyGoalMinutes, in: 15...360, step: 15) {
                Text("\(model.dailyGoalMinutes) minutes").font(Ink.mono(24))
            }
            Text("\(model.todayFocusSeconds / 60) minutes of focus today.").foregroundStyle(Ink.muted)
            HStack { Spacer(); Button("Done") { dismiss() }.buttonStyle(InkButtonStyle()).keyboardShortcut(.cancelAction) }
        }.padding(28).frame(width: 420).font(Ink.sans()).foregroundStyle(Ink.text).background(Ink.paper)
    }
}

struct StudyBrowser: View {
    @ObservedObject var model: FocusModel
    @Environment(\.dismiss) private var dismiss
    @State private var address = "https://www.wikipedia.org"
    @State private var blockedURL: URL?
    @State private var addressError = ""
    @State private var webView = WKWebView()
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { webView.goBack() } label: { Image(systemName: "chevron.left") }.disabled(!webView.canGoBack)
                    .accessibilityLabel("Back")
                Button { webView.goForward() } label: { Image(systemName: "chevron.right") }.disabled(!webView.canGoForward)
                    .accessibilityLabel("Forward")
                TextField("Enter a website", text: $address).font(Ink.mono(13)).textFieldStyle(.plain)
                    .padding(10).background(.white, in: RoundedRectangle(cornerRadius: 4)).onSubmit(load)
                Button(action: load) { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Load address")
                Button { dismiss() } label: { Image(systemName: "xmark") }.keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close study browser")
            }.buttonStyle(.plain).padding(16).background(Ink.rail)
            if !addressError.isEmpty { Text(addressError).font(Ink.sans(12)).foregroundStyle(Ink.rust).padding(10) }
            if let blockedURL {
                VStack(spacing: 20) {
                    Text("This site is blocked").font(Ink.title(28))
                    Text("\(blockedURL.host ?? "This site") is on your block list.").foregroundStyle(Ink.muted)
                    Text("Enter another address to continue.").font(Ink.sans(12)).foregroundStyle(Ink.muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Ink.paper)
            } else {
                BrowserWebView(webView: webView, model: model, address: $address, blockedURL: $blockedURL)
            }
            InkRule()
            HStack {
                Text(model.blockedDomains.isEmpty ? "No blocked sites" : "Blocked: \(model.blockedDomains.joined(separator: " · "))")
                    .lineLimit(1).help(model.blockedDomains.joined(separator: ", "))
                Spacer()
                Text("Study Browser")
            }.font(Ink.sans(11)).foregroundStyle(Ink.muted).padding(12).background(Ink.rail)
        }.font(Ink.sans()).foregroundStyle(Ink.text).background(Ink.paper).onAppear(perform: load)
            .onChange(of: model.blockedDomains) { _ in
                if let url = webView.url, model.isBlocked(url) { webView.stopLoading(); blockedURL = url }
            }
    }
    private func load() {
        var value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.contains("://") { value = "https://" + value }
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
            addressError = "Enter a valid website address."; return
        }
        addressError = ""
        address = url.absoluteString
        if model.isBlocked(url) { webView.stopLoading(); blockedURL = url; return }
        blockedURL = nil
        webView.load(URLRequest(url: url))
    }
}

struct BrowserWebView: NSViewRepresentable {
    let webView: WKWebView
    @ObservedObject var model: FocusModel
    @Binding var address: String
    @Binding var blockedURL: URL?
    func makeCoordinator() -> Coordinator { Coordinator(model: model, address: $address, blockedURL: $blockedURL) }
    func makeNSView(context: Context) -> WKWebView { webView.navigationDelegate = context.coordinator; return webView }
    func updateNSView(_ nsView: WKWebView, context: Context) { context.coordinator.model = model }
    final class Coordinator: NSObject, WKNavigationDelegate {
        var model: FocusModel
        @Binding var address: String
        @Binding var blockedURL: URL?
        init(model: FocusModel, address: Binding<String>, blockedURL: Binding<URL?>) {
            self.model = model; self._address = address; self._blockedURL = blockedURL
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
            if model.isBlocked(url) {
                address = url.absoluteString; blockedURL = url; decisionHandler(.cancel)
            } else if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request); decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url { address = url.absoluteString }
        }
    }
}
