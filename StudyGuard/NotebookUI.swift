import AppKit
import SwiftUI

struct NotebookView: View {
    @ObservedObject var model: NotebookModel
    @ObservedObject var focusModel: FocusModel
    @State private var tab = 0
    @State private var question = ""
    @State private var showNew = false
    @State private var showRename = false
    @State private var showPaste = false
    @State private var showWebsite = false
    @State private var showNotes = false
    @State private var deleteNotebook = false
    @State private var clearChat = false
    @State private var sourceToDelete: NotebookSource?
    @State private var sourcePreview: NotebookSource?
    @State private var citationPreview: NotebookCitation?
    @State private var artifactPreview: NotebookArtifact?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            toolbar
            if !model.storageError.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.storageError).font(Ink.sans(13)).foregroundStyle(Ink.rust)
                    HStack {
                        Button("Open library folder") { NSWorkspace.shared.open(model.libraryFolder) }
                        if model.libraryAvailable { Button("Retry saving") { model.retrySave() } }
                    }.buttonStyle(.bordered)
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Ink.rail)
            }
            if let notebook = model.selected {
                HStack(alignment: .top, spacing: 24) {
                    sources(notebook).frame(width: 220)
                    Rectangle().fill(Ink.line).frame(width: 1, height: 540)
                    workspace(notebook).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if model.libraryAvailable {
                VStack(alignment: .leading, spacing: 16) {
                    Text("A place for your study material").font(Ink.title(22))
                    Text("Create a notebook, add sources, and turn what you read into notes and practice.").foregroundStyle(Ink.muted)
                    Button("Create notebook") { showNew = true }.buttonStyle(InkButtonStyle())
                }.padding(.vertical, 40)
            }
            InkRule()
            HStack(spacing: 10) {
                if model.isWorking {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { model.cancel() }.buttonStyle(.plain).foregroundStyle(Ink.blue)
                }
                Text(model.status).font(Ink.sans(12)).foregroundStyle(Ink.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $showNew) { NotebookTitleEditor(model: model, isNew: true) }
        .sheet(isPresented: $showRename) { NotebookTitleEditor(model: model, isNew: false) }
        .sheet(isPresented: $showPaste) { NotebookPasteEditor(model: model) }
        .sheet(isPresented: $showWebsite) { NotebookWebsiteEditor(model: model, focusModel: focusModel) }
        .sheet(isPresented: $showNotes) { NotebookNotesEditor(model: model) }
        .sheet(item: $sourcePreview) { source in NotebookReader(title: source.title, subtitle: source.origin, text: source.text) }
        .sheet(item: $citationPreview) { citation in
            NotebookReader(title: "[\(citation.label)] \(citation.sourceTitle)", subtitle: citation.page.map { "Page \($0)" } ?? "Source excerpt", text: citation.excerpt)
        }
        .sheet(item: $artifactPreview) { artifact in NotebookArtifactView(artifact: artifact) }
        .alert("Study Notebook", isPresented: Binding(get: { !model.error.isEmpty }, set: { if !$0 { model.error = "" } })) {
            Button("OK") { model.error = "" }
        } message: { Text(model.error) }
        .confirmationDialog("Delete this notebook and its sources, notes, chat, and study materials?", isPresented: $deleteNotebook, titleVisibility: .visible) {
            Button("Delete notebook", role: .destructive) { model.deleteNotebook() }
        }
        .confirmationDialog("Clear this notebook's chat?", isPresented: $clearChat, titleVisibility: .visible) {
            Button("Clear chat", role: .destructive) { model.clearChat() }
        }
        .confirmationDialog("Remove this source from the notebook?", isPresented: Binding(get: { sourceToDelete != nil }, set: { if !$0 { sourceToDelete = nil } }), titleVisibility: .visible) {
            Button("Remove source", role: .destructive) {
                if let source = sourceToDelete { model.removeSource(source.id) }
                sourceToDelete = nil
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if !model.notebooks.isEmpty {
                Picker("Notebook", selection: $model.selectedID) {
                    ForEach(model.notebooks) { notebook in Text(notebook.title).tag(Optional(notebook.id)) }
                }.labelsHidden().frame(maxWidth: 300).disabled(model.isWorking)
            }
            Menu {
                Button("New notebook") { showNew = true }
                if model.selected != nil {
                    Button("Rename notebook") { showRename = true }
                    Button("Export notebook…") { model.exportNotebook() }
                    Divider()
                    Button("Delete notebook…", role: .destructive) { deleteNotebook = true }
                }
            } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("Notebook actions") }
                .menuStyle(.borderlessButton).frame(width: 26).disabled(model.isWorking || !model.libraryAvailable)
            Spacer()
            if focusModel.isRunning {
                Button { focusModel.activeTab = 0 } label: {
                    Text("\(focusModel.isBreak ? "Break" : "Focus") · \(focusModel.timeString)").font(Ink.mono(12)).foregroundStyle(Ink.blue)
                }.buttonStyle(.plain).accessibilityLabel("Return to running timer")
            }
        }
    }

    private func sources(_ notebook: StudyNotebook) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SOURCES").font(Ink.mono(11)).foregroundStyle(Ink.muted)
                Spacer()
                Text("\(notebook.sources.count)").font(Ink.mono(11)).foregroundStyle(Ink.muted)
            }
            Menu("Add source") {
                Button("Import PDF or document…") { model.importDocuments() }
                Button("Paste text…") { showPaste = true }
                Button("Add website…") { showWebsite = true }
            }.menuStyle(.borderlessButton).padding(10).background(Ink.selected, in: RoundedRectangle(cornerRadius: 4))
                .disabled(model.isWorking || !model.libraryAvailable)
            if notebook.sources.isEmpty {
                Text("Add a PDF, text document, website, or pasted notes. AI answers use excerpts from these sources.")
                    .font(Ink.sans(13)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(notebook.sources) { source in
                        HStack(alignment: .top, spacing: 8) {
                            Button { sourcePreview = source } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(source.title).font(Ink.sans(14, .medium)).foregroundStyle(Ink.text).lineLimit(2)
                                    Text(source.pages.map { "\($0.count) readable pages" } ?? "\(source.text.count.formatted()) characters")
                                        .font(Ink.sans(11)).foregroundStyle(Ink.muted)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                            Button { sourceToDelete = source } label: { Image(systemName: "xmark").font(.system(size: 10)).foregroundStyle(Ink.muted).padding(4) }
                                .buttonStyle(.plain).disabled(model.isWorking).accessibilityLabel("Remove \(source.title)")
                        }.padding(.vertical, 12)
                        InkRule()
                    }
                }
            }.frame(maxHeight: 260)
            Text("PDF, TXT, Markdown, RTF · up to 20 MB per document. Webpages up to 2 MB. Sources up to 500,000 characters.")
                .font(Ink.sans(11)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
            InkRule().padding(.vertical, 6)
            modelConnection
        }
    }

    private var modelConnection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LOCAL AI").font(Ink.mono(11)).foregroundStyle(Ink.muted)
            Text("Use Ollama on this Mac for chat and study tools. Your sources stay on this Mac.")
                .font(Ink.sans(12)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true)
            TextField("Model name", text: $model.modelName).textFieldStyle(.roundedBorder).disabled(model.isWorking)
                .accessibilityLabel("Ollama model name")
            if !model.availableModels.isEmpty {
                Menu("Choose installed model") {
                    ForEach(model.availableModels, id: \.self) { name in Button(name) { model.modelName = name } }
                }.disabled(model.isWorking)
            }
            Button("Check connection") { model.checkConnection() }.buttonStyle(.bordered).disabled(model.isWorking)
            DisclosureGroup("Set up Ollama") {
                VStack(alignment: .leading, spacing: 8) {
                    Link("Download Ollama ↗", destination: URL(string: "https://ollama.com/download/mac")!)
                    Text("Install and open Ollama, then download a model. For example, run this in Terminal:").font(Ink.sans(12)).foregroundStyle(Ink.muted)
                    Text("ollama pull llama3.2").font(Ink.mono(11)).textSelection(.enabled)
                    Text("Sources and notes work without a model.").font(Ink.sans(12)).foregroundStyle(Ink.muted)
                }.padding(.top, 8)
            }.font(Ink.sans(12))
        }
    }

    @ViewBuilder
    private func workspace(_ notebook: StudyNotebook) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("Notebook section", selection: $tab) {
                Text("Chat").tag(0)
                Text("Notes").tag(1)
                Text("Study tools").tag(2)
            }.pickerStyle(.segmented)
            if tab == 0 { chat(notebook) }
            else if tab == 1 { notes(notebook) }
            else { tools(notebook) }
        }
    }

    private func chat(_ notebook: StudyNotebook) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !notebook.messages.isEmpty {
                HStack { Spacer(); Button("Clear chat…") { clearChat = true }.buttonStyle(.plain).font(Ink.sans(12)).foregroundStyle(Ink.muted).disabled(model.isWorking) }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if notebook.messages.isEmpty {
                            Text("Ask your sources").font(Ink.title(22)).padding(.top, 20)
                            Text("Ask a question about your material. Click a citation to read the passage behind an answer.").foregroundStyle(Ink.muted)
                        }
                        ForEach(notebook.messages) { message in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(message.role == "user" ? "YOU" : "STUDY ASSISTANT").font(Ink.mono(10)).foregroundStyle(Ink.muted)
                                Text(message.text).font(Ink.sans(14)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                if message.role == "assistant" {
                                    if message.citations.isEmpty {
                                        Text("No source citations returned. Check this answer against your sources.").font(Ink.sans(11)).foregroundStyle(Ink.rust)
                                    } else {
                                        citationButtons(message.citations)
                                    }
                                }
                            }.padding(14).background(message.role == "user" ? Ink.rail : Ink.field, in: RoundedRectangle(cornerRadius: 5))
                        }
                        Color.clear.frame(height: 1).id("end")
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: 350)
                    .onChange(of: notebook.messages.count) { _ in proxy.scrollTo("end", anchor: .bottom) }
                    .onAppear { proxy.scrollTo("end", anchor: .bottom) }
            }
            HStack(spacing: 10) {
                TextField("Ask a question about your sources", text: $question).textFieldStyle(.roundedBorder).onSubmit(submitQuestion)
                    .disabled(!model.canGenerate)
                Button("Ask", action: submitQuestion).buttonStyle(InkButtonStyle()).disabled(!model.canGenerate || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("AI answers use selected source excerpts and may contain mistakes.").font(Ink.sans(11)).foregroundStyle(Ink.muted)
        }
    }

    private func submitQuestion() {
        guard model.canGenerate, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        model.ask(question)
        question = ""
    }

    private func notes(_ notebook: StudyNotebook) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Your notes").font(Ink.title(22))
                Spacer()
                Button("Edit notes") { showNotes = true }.buttonStyle(InkButtonStyle()).disabled(!model.libraryAvailable)
            }
            Text(notebook.notes.isEmpty ? "Write down what you learn, collect ideas, and keep your study plan here. Notes are saved in this notebook." : notebook.notes)
                .textSelection(.enabled).font(Ink.sans(14)).foregroundStyle(notebook.notes.isEmpty ? Ink.muted : Ink.text)
                .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        }
    }

    private func tools(_ notebook: StudyNotebook) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Turn reading into practice").font(Ink.title(22))
            Text("Generate study material from selected excerpts. Open a quiz to check your answers, or flip through flashcards.")
                .font(Ink.sans(13)).foregroundStyle(Ink.muted)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(NotebookTool.allCases) { tool in
                    Button(tool.title) { model.generate(tool) }.buttonStyle(InkButtonStyle(primary: false)).disabled(!model.canGenerate)
                }
            }
            InkRule()
            if notebook.artifacts.isEmpty { Text("Generated study materials will be saved here.").font(Ink.sans(13)).foregroundStyle(Ink.muted) }
            ForEach(notebook.artifacts) { artifact in
                HStack {
                    Button { artifactPreview = artifact } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(artifact.tool.title).font(Ink.sans(14, .medium)).foregroundStyle(Ink.blue)
                            Text(artifact.createdAt.formatted(date: .abbreviated, time: .shortened)).font(Ink.sans(11)).foregroundStyle(Ink.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                    Menu {
                        Button("Delete material", role: .destructive) { model.removeArtifact(artifact.id) }
                    } label: { Image(systemName: "ellipsis").accessibilityLabel("Study material actions") }
                        .menuStyle(.borderlessButton).frame(width: 22).disabled(model.isWorking)
                }.padding(.vertical, 8)
                InkRule()
            }
        }
    }

    private func citationButtons(_ citations: [NotebookCitation]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(citations) { citation in
                Button { citationPreview = citation } label: {
                    Text("[\(citation.label)] \(citation.sourceTitle)\(citation.page.map { " · p. \($0)" } ?? "")").font(Ink.sans(12)).foregroundStyle(Ink.blue).lineLimit(2)
                }.buttonStyle(.plain)
            }
        }
    }
}

struct NotebookTitleEditor: View {
    @ObservedObject var model: NotebookModel
    var isNew: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SheetHeading(title: isNew ? "New notebook" : "Rename notebook") { dismiss() }
            TextField("Notebook title", text: $title).textFieldStyle(.roundedBorder).onSubmit(save)
            HStack {
                Spacer()
                Button("Save", action: save).buttonStyle(InkButtonStyle()).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(28).frame(width: 420).font(Ink.sans()).foregroundStyle(Ink.text).background(Ink.paper)
            .onAppear { if !isNew { title = model.selected?.title ?? "" } }
    }
    private func save() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if isNew { model.createNotebook(title: title) } else { model.renameNotebook(title) }
        dismiss()
    }
}

struct NotebookPasteEditor: View {
    @ObservedObject var model: NotebookModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SheetHeading(title: "Paste a source") { dismiss() }
            TextField("Source title", text: $title).textFieldStyle(.roundedBorder)
            TextEditor(text: $text).font(Ink.sans(14)).frame(height: 310).border(Ink.line)
            HStack {
                Text("\(text.count.formatted()) / 500,000 characters").font(Ink.sans(12)).foregroundStyle(Ink.muted)
                Spacer()
                Button("Add source") { if model.addText(title: title, text: text) { dismiss() } }
                    .buttonStyle(InkButtonStyle()).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 500_000)
            }
        }.padding(28).frame(width: 620).font(Ink.sans()).foregroundStyle(Ink.text).background(Ink.paper)
    }
}

struct NotebookWebsiteEditor: View {
    @ObservedObject var model: NotebookModel
    @ObservedObject var focusModel: FocusModel
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var error = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SheetHeading(title: "Add a website") { dismiss() }
            TextField("https://example.com/article", text: $address).textFieldStyle(.roundedBorder).onSubmit(add)
            Text("StudyGuard saves the page's readable text. Pages that need a login or JavaScript may need you to paste the text instead.")
                .font(Ink.sans(13)).foregroundStyle(Ink.muted)
            if !error.isEmpty { Text(error).font(Ink.sans(12)).foregroundStyle(Ink.rust) }
            HStack { Spacer(); Button("Add website", action: add).buttonStyle(InkButtonStyle()).disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(28).frame(width: 500).font(Ink.sans()).foregroundStyle(Ink.text).background(Ink.paper)
    }
    private func add() {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value.contains("://") ? value : "https://" + value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
            error = "Enter a valid website address."; return
        }
        if focusModel.isRunning && !focusModel.isBreak && focusModel.isBlocked(url) {
            error = "This website is on your focus block list. Add it after your session ends."; return
        }
        model.addWebsite(value)
        dismiss()
    }
}

struct NotebookNotesEditor: View {
    @ObservedObject var model: NotebookModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SheetHeading(title: "Your notes") { dismiss() }
            TextEditor(text: $text).font(Ink.sans(14)).frame(height: 360).border(Ink.line)
            HStack { Spacer(); Button("Save notes") { model.updateNotes(text); dismiss() }.buttonStyle(InkButtonStyle()) }
        }.padding(28).frame(width: 660).font(Ink.sans()).foregroundStyle(Ink.text).background(Ink.paper)
            .onAppear { text = model.selected?.notes ?? "" }
    }
}

struct NotebookReader: View {
    var title: String
    var subtitle: String
    var text: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SheetHeading(title: title) { dismiss() }
            Text(subtitle).font(Ink.sans(12)).foregroundStyle(Ink.muted).textSelection(.enabled)
            InkRule()
            ScrollView { Text(text).font(Ink.sans(14)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 400)
            HStack { Spacer(); Button("Done") { dismiss() }.buttonStyle(InkButtonStyle()) }
        }.padding(28).frame(width: 700).foregroundStyle(Ink.text).background(Ink.paper)
    }
}

struct NotebookArtifactView: View {
    let artifact: NotebookArtifact
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var reveal = false
    @State private var selectedOption: Int?
    @State private var checked = false
    @State private var citation: NotebookCitation?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SheetHeading(title: artifact.tool.title) { dismiss() }
            Text("Generated from source excerpts. Check the citations as you study.").font(Ink.sans(12)).foregroundStyle(Ink.muted)
            InkRule()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if artifact.tool == .flashcards, artifact.cards.indices.contains(index) {
                        let card = artifact.cards[index]
                        Text("CARD \(index + 1) / \(artifact.cards.count)").font(Ink.mono(11)).foregroundStyle(Ink.muted)
                        Text(card.front).font(Ink.title(24)).frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                        Button(reveal ? "Hide answer" : "Reveal answer") { reveal.toggle() }.buttonStyle(InkButtonStyle())
                        if reveal {
                            Text(card.back).font(Ink.sans(16)).textSelection(.enabled)
                            citations(card.citations)
                        }
                    } else if artifact.tool == .quiz, artifact.questions.indices.contains(index) {
                        let item = artifact.questions[index]
                        Text("QUESTION \(index + 1) / \(artifact.questions.count)").font(Ink.mono(11)).foregroundStyle(Ink.muted)
                        Text(item.question).font(Ink.title(22))
                        ForEach(item.options.indices, id: \.self) { option in
                            Button { selectedOption = option } label: {
                                HStack(alignment: .top) {
                                    Image(systemName: selectedOption == option ? "largecircle.fill.circle" : "circle")
                                    Text(item.options[option]).frame(maxWidth: .infinity, alignment: .leading)
                                    if checked && option == item.answerIndex { Image(systemName: "checkmark").accessibilityLabel("Correct answer") }
                                }.padding(12).foregroundStyle(checked && option == item.answerIndex ? Ink.blue : Ink.text)
                                    .background(selectedOption == option ? Ink.selected : Ink.rail, in: RoundedRectangle(cornerRadius: 4))
                            }.buttonStyle(.plain).disabled(checked)
                        }
                        Button("Check answer") { checked = true }.buttonStyle(InkButtonStyle()).disabled(selectedOption == nil || checked)
                        if checked {
                            Text(selectedOption == item.answerIndex ? "Correct." : "Correct answer: \(item.options[item.answerIndex])").font(Ink.sans(15, .medium)).foregroundStyle(Ink.blue)
                            Text(item.explanation).font(Ink.sans(14))
                            citations(item.citations)
                        }
                    } else {
                        Text(artifact.text).font(Ink.sans(15)).textSelection(.enabled)
                        citations(artifact.citations.map(\.label))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(height: 400)
            if artifact.tool == .quiz || artifact.tool == .flashcards {
                let count = artifact.tool == .quiz ? artifact.questions.count : artifact.cards.count
                HStack {
                    Button("Previous") { move(-1) }.disabled(index == 0)
                    Spacer()
                    Button(index == count - 1 ? "Start again" : "Next") { if index == count - 1 { index = -1 }; move(1) }
                }.buttonStyle(.bordered)
            }
        }.padding(28).frame(width: 700).font(Ink.sans()).foregroundStyle(Ink.text).background(Ink.paper)
            .sheet(item: $citation) { value in NotebookReader(title: "[\(value.label)] \(value.sourceTitle)", subtitle: value.page.map { "Page \($0)" } ?? "Source excerpt", text: value.excerpt) }
    }
    private func move(_ amount: Int) { index += amount; reveal = false; checked = false; selectedOption = nil }
    private func citations(_ labels: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if labels.isEmpty { Text("No source citations returned. Check this material against your sources.").font(Ink.sans(12)).foregroundStyle(Ink.rust) }
            ForEach(artifact.citations.filter { labels.contains($0.label) }) { value in
                Button("[\(value.label)] \(value.sourceTitle)\(value.page.map { " · p. \($0)" } ?? "")") { citation = value }
                    .buttonStyle(.plain).font(Ink.sans(13)).foregroundStyle(Ink.blue)
            }
        }
    }
}
