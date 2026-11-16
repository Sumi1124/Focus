import AppKit
import Combine
import EventKit
import Foundation

/// Optional link to Apple Calendar. Events are read and written on this Mac only through macOS's own
/// Calendar permission; nothing from the calendar is sent anywhere unless you pick it as your session name.
@MainActor
final class CalendarLink: ObservableObject {
    @Published private(set) var suggestEnabled: Bool
    @Published private(set) var logEnabled: Bool
    @Published var status = ""

    private let store = EKEventStore()
    private let defaults: UserDefaults
    static let eventPrefix = "StudyGuard: "

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        suggestEnabled = defaults.bool(forKey: "calendar.suggest")
        logEnabled = defaults.bool(forKey: "calendar.log")
    }

    var hasAccess: Bool {
        let current = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) { return current == .fullAccess }
        return current == .authorized
    }

    private func requestAccess() async -> Bool {
        if hasAccess { return true }
        do {
            if #available(macOS 14.0, *) { return try await store.requestFullAccessToEvents() }
            return try await store.requestAccess(to: .event)
        } catch {
            return false
        }
    }

    private func ensureAccess() async -> Bool {
        guard await requestAccess() else {
            status = "Calendar access was not allowed. Turn it on for StudyGuard in System Settings → Privacy & Security → Calendars."
            return false
        }
        return true
    }

    func setSuggest(_ value: Bool) async {
        if value, !(await ensureAccess()) { return }
        suggestEnabled = value
        defaults.set(value, forKey: "calendar.suggest")
        status = value ? "StudyGuard will suggest your current calendar event when you start a session." : ""
    }

    func setLog(_ value: Bool) async {
        if value, !(await ensureAccess()) { return }
        logEnabled = value
        defaults.set(value, forKey: "calendar.log")
        status = value ? "Finished focus sessions will be added to your default calendar." : ""
    }

    /// The title of the event happening now (or starting within 30 minutes), if any.
    func suggestedTopic() -> String? {
        guard suggestEnabled, hasAccess else { return nil }
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-3600), end: now.addingTimeInterval(1800), calendars: nil)
        let events = store.events(matching: predicate)
            .filter { event in
                let title = (event.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return !event.isAllDay && event.endDate > now && !title.isEmpty && !title.hasPrefix(Self.eventPrefix)
            }
            .sorted { $0.startDate < $1.startDate }
        let chosen = events.first { $0.startDate <= now } ?? events.first
        return chosen?.title.map { RelevanceRules.sanitize($0, limit: 100) }
    }

    /// Adds a finished focus session to the default calendar.
    func logSession(subject: String, start: Date, seconds: Int) {
        guard logEnabled, hasAccess, seconds >= 60, let calendar = store.defaultCalendarForNewEvents else { return }
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = Self.eventPrefix + subject
        event.startDate = start
        event.endDate = start.addingTimeInterval(TimeInterval(seconds))
        event.notes = "Logged by StudyGuard."
        try? store.save(event, span: .thisEvent)
    }
}
