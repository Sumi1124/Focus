import AppKit

@MainActor
final class UpdateSetupDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var statusLabel: NSTextField!
    private var action: NSButton!
    private var progress: NSProgressIndicator!
    private var signatureJSON: String?
    private var preparing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 365),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "StudyGuard Update Setup"
        window.center()
        window.isReleasedWhenClosed = false
        let content = NSView()
        window.contentView = content

        let title = NSTextField(labelWithString: "Enable updates inside StudyGuard")
        title.font = .boldSystemFont(ofSize: 21)
        let explanation = NSTextField(wrappingLabelWithString: "Prepare the published StudyGuard 1.6.0 update using the existing key on this Mac. macOS may ask you to allow Keychain access. Your private key stays on your Mac.")
        explanation.font = .systemFont(ofSize: 14)
        let instructions = NSTextField(wrappingLabelWithString: "When ready, paste the copied result into your Codex chat. Codex can then enable Install and Relaunch in StudyGuard.")
        instructions.font = .systemFont(ofSize: 14)
        statusLabel = NSTextField(wrappingLabelWithString: "Use the Mac that created StudyGuard 1.4.")
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabelColor
        action = NSButton(title: "Prepare Update", target: self, action: #selector(prepareOrCopy))
        action.bezelStyle = .rounded
        action.keyEquivalent = "\r"
        progress = NSProgressIndicator()
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        let buttons = NSStackView(views: [progress, action])
        buttons.orientation = .horizontal
        buttons.spacing = 12
        let stack = NSStackView(views: [title, explanation, instructions, statusLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24)
        ])
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @objc private func prepareOrCopy() {
        if let text = signatureJSON {
            copyResult(text)
            return
        }
        guard !preparing else { return }
        preparing = true
        action.isEnabled = false
        progress.startAnimation(nil)
        statusLabel.stringValue = "Downloading and checking StudyGuard 1.6.0…"
        Task {
            do {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForResource = 180
                let session = URLSession(configuration: configuration)
                defer { session.invalidateAndCancel() }
                let (archive, response) = try await session.data(from: PublishedUpdate.downloadURL)
                guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                    throw UpdateSetupFailure(message: "The update could not be downloaded. Check your connection and try again.")
                }
                try PublishedUpdate.verifyArchive(archive)
                let toolURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/sign_update")
                guard FileManager.default.isExecutableFile(atPath: toolURL.path) else {
                    throw UpdateSetupFailure(message: "The signing tool is missing. Download Update Setup again.")
                }
                statusLabel.stringValue = "Using your existing StudyGuard key. Allow the Keychain request if it appears…"
                let result = try await Task.detached(priority: .userInitiated) {
                    try PublishedUpdate.sign(archive: archive, toolURL: toolURL)
                }.value
                signatureJSON = result
                copyResult(result)
                action.title = "Copy Result Again"
            } catch {
                statusLabel.stringValue = error.localizedDescription
                action.title = "Try Again"
            }
            preparing = false
            action.isEnabled = true
            progress.stopAnimation(nil)
        }
    }

    private func copyResult(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        statusLabel.stringValue = "Ready and copied. Return to your Codex chat, paste (⌘V), and send. The copied result contains only the public update signature."
    }
}

@main
struct UpdateSetup {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = UpdateSetupDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
