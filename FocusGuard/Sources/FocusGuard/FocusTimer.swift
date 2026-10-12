import Foundation

@MainActor
final class FocusTimer: ObservableObject {
    @Published var remainingSeconds = 25 * 60
    @Published var isRunning = false
    @Published var didFinish = false

    private var timer: Timer?

    var timeText: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    func configure(minutes: Int) {
        guard !isRunning else { return }
        remainingSeconds = minutes * 60
        didFinish = false
    }

    func start() {
        guard !isRunning, remainingSeconds > 0 else { return }
        didFinish = false
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func stop() {
        pause()
        didFinish = false
    }

    private func tick() {
        guard remainingSeconds > 1 else {
            remainingSeconds = 0
            pause()
            didFinish = true
            NSSound.beep()
            return
        }
        remainingSeconds -= 1
    }
}
