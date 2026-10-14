import Foundation

struct NotebookPage: Codable {
    var number: Int
    var text: String
}

struct NotebookSource: Codable, Identifiable {
    var id = UUID()
    var title: String
    var text: String
    var origin: String
    var pages: [NotebookPage]? = nil
    var addedAt = Date()
}

struct NotebookCitation: Codable, Identifiable {
    var label: String
    var sourceID: UUID
    var sourceTitle: String
    var excerpt: String
    var page: Int?
    var id: String { label }
}

struct NotebookMessage: Codable, Identifiable {
    var id = UUID()
    var role: String
    var text: String
    var citations: [NotebookCitation] = []
}

struct StudyCard: Codable {
    var front: String
    var back: String
    var citations: [String]
}

struct StudyQuestion: Codable {
    var question: String
    var options: [String]
    var answerIndex: Int
    var explanation: String
    var citations: [String]
}

enum NotebookTool: String, Codable, CaseIterable, Identifiable {
    case summary, keyPoints, quiz, flashcards
    var id: String { rawValue }
    var title: String {
        switch self {
        case .summary: return "Summary"
        case .keyPoints: return "Key points"
        case .quiz: return "Quiz"
        case .flashcards: return "Flashcards"
        }
    }
    var instruction: String {
        switch self {
        case .summary: return "Summarize the supplied source excerpts. Cite every main point using [S1] style markers."
        case .keyPoints: return "List the main ideas and definitions in the supplied source excerpts. Cite each point using [S1] style markers."
        case .quiz:
            return "Create 5 multiple-choice questions from the supplied excerpts. Return only JSON: {\"questions\":[{\"question\":\"...\",\"options\":[\"...\",\"...\",\"...\",\"...\"],\"answerIndex\":0,\"explanation\":\"...\",\"citations\":[\"S1\"]}]}. answerIndex is zero-based. Include only citation labels provided with the excerpts."
        case .flashcards:
            return "Create 8 study flashcards from the supplied excerpts. Return only JSON: {\"cards\":[{\"front\":\"...\",\"back\":\"...\",\"citations\":[\"S1\"]}]}. Include only citation labels provided with the excerpts."
        }
    }
}

struct NotebookArtifact: Codable, Identifiable {
    var id = UUID()
    var tool: NotebookTool
    var text: String
    var citations: [NotebookCitation]
    var cards: [StudyCard] = []
    var questions: [StudyQuestion] = []
    var createdAt = Date()
}

struct StudyNotebook: Codable, Identifiable {
    var id = UUID()
    var title: String
    var sources: [NotebookSource] = []
    var notes = ""
    var messages: [NotebookMessage] = []
    var artifacts: [NotebookArtifact] = []
}

enum NotebookRetrieval {
    // Small, deterministic local retrieval; only selected excerpts go to the model.
    static func excerpts(query: String, sources: [NotebookSource], overview: Bool = false) -> [NotebookCitation] {
        let terms = Set(query.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 })
        var candidates: [(citation: NotebookCitation, score: Int)] = []
        for source in sources {
            let pages = source.pages ?? [NotebookPage(number: 0, text: source.text)]
            for page in pages {
                var start = page.text.startIndex
                while start < page.text.endIndex {
                    let end = page.text.index(start, offsetBy: 1200, limitedBy: page.text.endIndex) ?? page.text.endIndex
                    let excerpt = String(page.text[start..<end])
                    let lower = excerpt.lowercased()
                    let score = terms.reduce(0) { $0 + (lower.contains($1) ? 1 : 0) }
                    candidates.append((NotebookCitation(label: "", sourceID: source.id, sourceTitle: source.title,
                                                        excerpt: excerpt, page: page.number == 0 ? nil : page.number), score))
                    if end == page.text.endIndex { break }
                    start = page.text.index(end, offsetBy: -100)
                }
            }
        }
        var chosen: [NotebookCitation] = []
        if overview {
            // Sample across every document, including the middle and end of long sources.
            let groups = sources.map { source in candidates.filter { $0.citation.sourceID == source.id } }
            for fraction in [0.0, 0.5, 1.0] {
                for group in groups where !group.isEmpty {
                    let item = group[Int(Double(group.count - 1) * fraction)].citation
                    if !chosen.contains(where: { $0.sourceID == item.sourceID && $0.excerpt == item.excerpt }) {
                        chosen.append(item)
                    }
                    if chosen.count == 10 { break }
                }
                if chosen.count == 10 { break }
            }
        } else {
            let ranked = candidates.enumerated().sorted {
                $0.element.score == $1.element.score ? $0.offset < $1.offset : $0.element.score > $1.element.score
            }
            chosen = ranked.prefix(10).map { $0.element.citation }
        }
        return chosen.enumerated().map { index, citation in
            var result = citation
            result.label = "S\(index + 1)"
            return result
        }
    }

    static func groundedText(_ text: String, citations: [NotebookCitation]) -> (String, [NotebookCitation]) {
        let regex = try! NSRegularExpression(pattern: #"\[S\d+\]"#)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var result = text
        var used = Set<String>()
        let available = Set(citations.map(\.label))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let label = String(result[range].dropFirst().dropLast())
            if available.contains(label) { used.insert(label) }
            else { result.removeSubrange(range) }
        }
        return (result, citations.filter { used.contains($0.label) })
    }

    static func artifact(tool: NotebookTool, response: String, citations: [NotebookCitation]) throws -> NotebookArtifact {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            var lines = cleaned.components(separatedBy: "\n")
            lines.removeFirst()
            if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" { lines.removeLast() }
            cleaned = lines.joined(separator: "\n")
        }
        let available = Set(citations.map(\.label))
        switch tool {
        case .flashcards:
            struct Result: Decodable { var cards: [StudyCard] }
            var cards = try JSONDecoder().decode(Result.self, from: Data(cleaned.utf8)).cards
            guard !cards.isEmpty, cards.count <= 30,
                  cards.allSatisfy({ !$0.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw NotebookError.message("The model did not return usable flashcards. Try again or choose another model.")
            }
            for index in cards.indices { cards[index].citations = cards[index].citations.filter { available.contains($0) } }
            return NotebookArtifact(tool: tool, text: "", citations: citations, cards: cards)
        case .quiz:
            struct Result: Decodable { var questions: [StudyQuestion] }
            var questions = try JSONDecoder().decode(Result.self, from: Data(cleaned.utf8)).questions
            guard !questions.isEmpty, questions.count <= 30,
                  questions.allSatisfy({ !$0.question.isEmpty && $0.options.count >= 2 && $0.options.count <= 6 && $0.options.allSatisfy({ !$0.isEmpty }) && $0.options.indices.contains($0.answerIndex) }) else {
                throw NotebookError.message("The model did not return a usable quiz. Try again or choose another model.")
            }
            for index in questions.indices { questions[index].citations = questions[index].citations.filter { available.contains($0) } }
            return NotebookArtifact(tool: tool, text: "", citations: citations, questions: questions)
        default:
            let (text, used) = groundedText(response, citations: citations)
            return NotebookArtifact(tool: tool, text: text, citations: used)
        }
    }
}

enum NotebookError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
