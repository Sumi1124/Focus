import SwiftUI

struct ContentView: View {
    @StateObject private var timer = FocusTimer()
    @State private var duration = 25
    @State private var selectedSites: Set<String> = ["YouTube", "Instagram"]
    @State private var status = "Pick a duration, then begin your focus session."
    @State private var alertText: String?

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.green)
                Text("FocusGuard")
                    .font(.largeTitle.bold())
                Text("Protect a little time for what matters.")
                    .foregroundStyle(.secondary)
            }

            Text(timer.timeText)
                .font(.system(size: 72, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .accessibilityLabel("\(timer.remainingSeconds / 60) minutes remaining")

            HStack {
                Text("Focus time")
                Spacer()
                Picker("Focus time", selection: $duration) {
                    ForEach([15, 25, 45, 50, 60, 90], id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                .labelsHidden()
                .disabled(timer.isRunning)
                .onChange(of: duration) { newValue in timer.configure(minutes: newValue) }
            }
            .padding(.horizontal)

            GroupBox("Block during this session") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(HostsBlocker.supportedSites.keys.sorted(), id: \.self) { site in
                        Toggle(site, isOn: Binding(
                            get: { selectedSites.contains(site) },
                            set: { enabled in
                                if enabled {
                                    selectedSites.insert(site)
                                } else {
                                    selectedSites.remove(site)
                                }
                            }
                        ))
                        .disabled(timer.isRunning)
                    }
                    Text("FocusGuard asks for your Mac administrator password only to add and later remove its own reversible website-blocking entries.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)

            Button(timer.isRunning ? "Pause" : "Start focus session") {
                timer.isRunning ? pause() : start()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!timer.isRunning && selectedSites.isEmpty)

            if timer.isRunning {
                Button("End session and unblock sites", role: .destructive, action: finishSession)
                    .buttonStyle(.borderless)
            } else {
                Button("Remove FocusGuard website block", action: removeBlock)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }

            Text(status)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(28)
        .alert("FocusGuard", isPresented: Binding(get: { alertText != nil }, set: { if !$0 { alertText = nil } })) {
            Button("OK", role: .cancel) { alertText = nil }
        } message: { Text(alertText ?? "") }
        .onChange(of: timer.didFinish) { finished in
            if finished { finishSession() }
        }
    }

    private func start() {
        do {
            try HostsBlocker.enable(for: selectedSites)
            timer.start()
            status = "Focus mode is on. Selected websites are blocked until you end the session."
        } catch { alertText = "Could not start focus mode: \(error.localizedDescription)" }
    }

    private func pause() { timer.pause(); status = "Timer paused. Websites remain blocked." }

    private func finishSession() {
        timer.stop()
        removeBlock()
    }

    private func removeBlock() {
        do {
            try HostsBlocker.disable()
            status = "Focus mode is off. Selected websites are available again."
        } catch { alertText = "Could not remove the website block: \(error.localizedDescription)" }
    }
}
