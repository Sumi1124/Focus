import AppKit
import Foundation

@main
@MainActor
struct NotebookChecks {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func main() async throws {
        _ = NSApplication.shared
        let suite = "StudyGuard.Checks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }

        // Settings and a running focus timer survive constructing a fresh app model.
        let initial = FocusModel(defaults: defaults)
        initial.setDuration(50)
        initial.selectMode(isBreak: true)
        initial.setDuration(10)
        let settings = FocusModel(defaults: defaults)
        expect(settings.duration == 50 && settings.breakDuration == 10 && settings.isBreak && settings.secondsLeft == 600, "Timer settings did not restore")
        settings.selectMode(isBreak: false)
        settings.toggleSession()
        let beforeCount = settings.sessionsStarted
        var snapshot = try JSONSerialization.jsonObject(with: defaults.data(forKey: "savedTimerState")!) as! [String: Any]
        let now = Date()
        snapshot["sessionStartedAt"] = now.addingTimeInterval(-30).timeIntervalSinceReferenceDate
        snapshot["accountedThrough"] = now.addingTimeInterval(-30).timeIntervalSinceReferenceDate
        snapshot["endDate"] = now.addingTimeInterval(120).timeIntervalSinceReferenceDate
        snapshot["sessionSeconds"] = 0
        snapshot["recordedDays"] = [String: Int]()
        defaults.set(try JSONSerialization.data(withJSONObject: snapshot), forKey: "savedTimerState")
        defaults.set(["2000-01-01": 999], forKey: "focusSecondsByDay")
        let resumed = FocusModel(defaults: defaults)
        expect(resumed.isRunning && (119...120).contains(resumed.secondsLeft), "Running timer did not restore its deadline")
        expect(resumed.totalFocusSeconds == 30, "Closed-app time was lost or inconsistent totals were double counted")
        expect(resumed.sessionsStarted == beforeCount, "Restoration counted a second session")
        resumed.toggleSession()
        let stopped = FocusModel(defaults: defaults)
        expect(!stopped.isRunning && stopped.history.count == 1 && stopped.history[0].seconds >= 30, "Ending a restored session did not save history")

        // Expiration during quit creates one completed session, including after a second launch.
        snapshot["sessionStartedAt"] = now.addingTimeInterval(-62).timeIntervalSinceReferenceDate
        snapshot["accountedThrough"] = now.addingTimeInterval(-62).timeIntervalSinceReferenceDate
        snapshot["endDate"] = now.addingTimeInterval(-2).timeIntervalSinceReferenceDate
        snapshot["recordedDays"] = [String: Int]()
        defaults.set(try JSONSerialization.data(withJSONObject: snapshot), forKey: "savedTimerState")
        let expired = FocusModel(defaults: defaults)
        expect(!expired.isRunning && expired.history.first?.completed == true && expired.history.first?.seconds == 60, "Expired session did not complete on launch")
        let reopened = FocusModel(defaults: defaults)
        expect(reopened.history.count == expired.history.count && reopened.totalFocusSeconds == 60, "Reopening duplicated a completed session")
        snapshot["isBreak"] = true
        snapshot["recordedDays"] = ["2000-01-01": 60]
        defaults.set(try JSONSerialization.data(withJSONObject: snapshot), forKey: "savedTimerState")
        let breakFinished = FocusModel(defaults: defaults)
        expect(!breakFinished.isRunning && breakFinished.isBreak && breakFinished.totalFocusSeconds == 60 && breakFinished.history.count == reopened.history.count, "Break restoration changed focus totals or history")
        print("PASS: timer settings, restart, accounting, completion, and break restoration")
        settings.toggleSession()

        // Notebook storage retains sources, notes, and selection across app launches.
        let library = NotebookModel(defaults: defaults, folder: folder)
        expect(library.addText(title: "Biology", text: "Photosynthesis uses light to make sugars."), "Text import failed")
        library.updateNotes("Revise chapter 3.")
        let restored = NotebookModel(defaults: defaults, folder: folder)
        expect(restored.selected?.sources.count == 1 && restored.selected?.notes == "Revise chapter 3.", "Notebook did not restore")
        restored.createNotebook(title: "Chemistry")
        let selected = NotebookModel(defaults: defaults, folder: folder)
        expect(selected.selected?.title == "Chemistry", "Selected notebook did not restore")
        let sourceURL = folder.appendingPathComponent("source.txt")
        try Data("A readable source.".utf8).write(to: sourceURL)
        let imported = try NotebookImporter.document(sourceURL)
        expect(imported.text == "A readable source.", "Document importer lost source text")
        do { try NotebookImporter.validate("  \n"); preconditionFailure("Empty sources must be rejected") } catch {}
        do { try NotebookImporter.validate(String(repeating: "x", count: 500_001)); preconditionFailure("Oversized sources must be rejected") } catch {}
        let corrupt = Data("invalid library".utf8)
        let libraryURL = folder.appendingPathComponent("notebooks.json")
        try corrupt.write(to: libraryURL)
        let damaged = NotebookModel(defaults: defaults, folder: folder)
        damaged.createNotebook(title: "Must not overwrite")
        expect(!damaged.libraryAvailable && !damaged.storageError.isEmpty, "Corrupt storage was silently replaced")
        let preserved = try Data(contentsOf: libraryURL)
        expect(preserved == corrupt, "Corrupt notebook library was overwritten")
        print("PASS: notebook storage, selection, document import, limits, and corruption preservation")

        // Retrieval must reach later passages and retain PDF page numbers.
        let source = NotebookSource(title: "Book", text: String(repeating: "introductory material ", count: 300) + "unique_tail_marker", origin: "Pasted text")
        let excerpts = NotebookRetrieval.excerpts(query: "unique_tail_marker", sources: [source])
        expect(excerpts.first?.excerpt.contains("unique_tail_marker") == true, "Retrieval missed a later passage")
        let overview = NotebookRetrieval.excerpts(query: "summary", sources: [source], overview: true)
        expect(overview.contains(where: { $0.excerpt.contains("unique_tail_marker") }), "Overview ignored the end of the source")
        let pdf = NotebookSource(title: "PDF", text: "page text", origin: "book.pdf", pages: [NotebookPage(number: 7, text: "Page seven material")])
        expect(NotebookRetrieval.excerpts(query: "seven", sources: [pdf]).first?.page == 7, "PDF citation lost its page number")
        let citation = NotebookCitation(label: "S1", sourceID: source.id, sourceTitle: source.title, excerpt: "Evidence", page: nil)
        let (answer, used) = NotebookRetrieval.groundedText("🌸 Evidence [S1]. Invented [S99].", citations: [citation])
        expect(answer.contains("[S1]") && !answer.contains("[S99]") && used.count == 1, "Citation validation accepted an invented marker or damaged Unicode")
        let cards = try NotebookRetrieval.artifact(tool: .flashcards, response: #"{"cards":[{"front":"Question","back":"Answer","citations":["S1","S99"]}]}"#, citations: [citation])
        expect(cards.cards.first?.citations == ["S1"], "Flashcards kept an invented citation")
        do {
            _ = try NotebookRetrieval.artifact(tool: .quiz, response: #"{"questions":[{"question":"Question","options":["A","B"],"answerIndex":4,"explanation":"Explanation","citations":[] }]}"#, citations: [citation])
            preconditionFailure("Invalid quiz answers must be rejected")
        } catch {}
        print("PASS: retrieval coverage, PDF page references, citation validation, and structured study tools")

        // Exercise the actual Ollama HTTP contract against a local test service.
        let ai = NotebookModel(defaults: defaults, folder: folder.appendingPathComponent("ai-checks"))
        expect(ai.addText(title: "Biology", text: "Photosynthesis uses light to make sugars."), "AI test source could not be saved")
        ai.checkConnection()
        try await waitForWork(ai)
        expect(ai.availableModels == ["test-model"] && ai.modelName == "test-model", "Model discovery did not use the local Ollama API")
        ai.ask("How does photosynthesis work?")
        try await waitForWork(ai)
        expect(ai.error.isEmpty && ai.selected?.messages.last?.role == "assistant", "AI chat did not finish")
        expect(ai.selected?.messages.last?.citations.count == 1 && ai.selected?.messages.last?.text.contains("S99") == false, "AI chat did not validate its source references")
        for tool in NotebookTool.allCases {
            ai.generate(tool)
            try await waitForWork(ai)
            expect(ai.error.isEmpty && ai.selected?.artifacts.first?.tool == tool, "AI study tool failed: \(tool.title)")
        }
        let savedAI = NotebookModel(defaults: defaults, folder: folder.appendingPathComponent("ai-checks"))
        expect(savedAI.selected?.artifacts.count == 4 && savedAI.selected?.messages.count == 2, "Generated material did not survive relaunch")
        ai.ask("return_error")
        try await waitForWork(ai)
        expect(ai.error.contains("simulated failure") && !ai.isWorking, "HTTP failures did not restore the interface")
        ai.error = ""
        let messagesBeforeCancel = ai.selected!.messages.count
        ai.ask("slow_request")
        try await Task.sleep(nanoseconds: 100_000_000)
        ai.cancel()
        try await waitForWork(ai)
        expect(!ai.isWorking && ai.error.isEmpty && ai.selected!.messages.count == messagesBeforeCancel + 1, "Cancelled AI request saved an unwanted answer or showed a connection error")
        ai.modelName = "hosted-model:latest-cloud"
        ai.ask("This source must stay local")
        try await waitForWork(ai)
        expect(ai.error.contains("local model") && ai.selected!.messages.last?.role == "user", "Hosted model was allowed to receive source material")
        print("PASS: local model discovery, cited chat, all study tools, HTTP failures, cancellation, and output persistence")
    }

    static func waitForWork(_ model: NotebookModel) async throws {
        for _ in 0..<100 {
            if !model.isWorking { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        preconditionFailure("Local AI operation did not finish within five seconds")
    }
}
