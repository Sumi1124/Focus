import Foundation

enum HostsBlockerError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let detail): return detail
        }
    }
}

/// Applies only a marked FocusGuard section, so removing a focus session never alters other hosts entries.
enum HostsBlocker {
    static let supportedSites = [
        "YouTube": ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"],
        "Instagram": ["instagram.com", "www.instagram.com"]
    ]

    static func enable(for siteNames: Set<String>) throws {
        let domains = siteNames.flatMap { supportedSites[$0] ?? [] }.sorted()
        let entries = domains.map { "127.0.0.1 \\($0)" }.joined(separator: "\\n")
        let script = """
        sed -i '' '/# FocusGuard BEGIN/,/# FocusGuard END/d' /etc/hosts
        cat >> /etc/hosts <<'FOCUSGUARD'
        # FocusGuard BEGIN
        \(entries)
        # FocusGuard END
        FOCUSGUARD
        dscacheutil -flushcache
        killall -HUP mDNSResponder 2>/dev/null || true
        """
        try runAsAdministrator(script)
    }

    static func disable() throws {
        let script = """
        sed -i '' '/# FocusGuard BEGIN/,/# FocusGuard END/d' /etc/hosts
        dscacheutil -flushcache
        killall -HUP mDNSResponder 2>/dev/null || true
        """
        try runAsAdministrator(script)
    }

    private static func runAsAdministrator(_ script: String) throws {
        guard let encoded = script.data(using: .utf8)?.base64EncodedString() else { return }
        let shellCommand = "echo \(encoded) | base64 -D | /bin/sh"
        let escaped = shellCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escaped)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: data, encoding: .utf8) ?? "Administrator permission was not granted."
            throw HostsBlockerError.commandFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
