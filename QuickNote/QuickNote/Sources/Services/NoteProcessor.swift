import Foundation

// MARK: - Constants

public let kClaudeModelID = "claude-haiku-4-5-20251001"
public let kUseMockProcessor = false

// MARK: - Enhancement modes

public enum EnhancementMode: String, CaseIterable {
    case clarity, expand, sharpen, reframe

    var label: String { rawValue.capitalized }

    var prompt: String {
        switch self {
        case .clarity:
            return "Rewrite the following note in clear, concise prose. Keep the exact same meaning and intent. Do not add information. Do not use bullet points. Return only the rewritten text, nothing else.\n\nNote: "
        case .expand:
            return "The following is a brief idea or fragment. Expand it into a structured note with 2-3 sentences of context and one clearly stated angle or direction. Do not add speculation beyond what is implied. Return only the expanded note.\n\nNote: "
        case .sharpen:
            return "The following contains one or more tasks. Rewrite each task to be specific, actionable, and time-aware where possible. Extract implied deadlines or urgency. Return as a clean list, one task per line, no bullet characters. Return only the sharpened tasks.\n\nNote: "
        case .reframe:
            return "The following note may be anxious, vague, or emotionally charged. Rewrite it as a calm, clear observation or structured list of concrete next steps. Do not dismiss or minimize the emotion — just translate it into something actionable and readable. Return only the reframed text.\n\nNote: "
        }
    }
}

// MARK: - API response types

public struct ProcessedNoteResponse: Codable {
    public let type: String
    public let tasks: [String]
    public let tags: [String]
    public let summary: String
}

// MARK: - Errors

public enum NoteProcessorError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case apiError(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:           return "Anthropic API key not configured"
        case .invalidURL:              return "Invalid API URL"
        case .networkError(let e):     return "Network error: \(e.localizedDescription)"
        case .invalidResponse:         return "Invalid response from API"
        case .decodingError(let e):    return "Failed to parse response: \(e.localizedDescription)"
        case .apiError(let msg):       return "API error: \(msg)"
        }
    }
}

// MARK: - NoteProcessor

@Observable
public final class NoteProcessor {
    private let apiKey: String
    private let useMock: Bool
    private let baseURL = "https://api.anthropic.com/v1/messages"

    public private(set) var isProcessing: Bool = false

    public init(apiKey: String? = nil, useMock: Bool = kUseMockProcessor) {
        // Priority: explicit arg → Secrets.swift → environment variable
        let resolved = apiKey
            ?? (Secrets.anthropicAPIKey.isEmpty ? nil : Secrets.anthropicAPIKey)
            ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
            ?? ""
        self.apiKey = resolved
        self.useMock = useMock
    }

    // MARK: - Note classification

    public func process(rawText: String) async throws -> ProcessedNoteResponse {
        isProcessing = true
        defer { isProcessing = false }
        return useMock ? await mockProcess(rawText: rawText) : try await apiProcess(rawText: rawText)
    }

    public func createNote(from rawText: String) async throws -> Note {
        let processed = try await process(rawText: rawText)
        let noteType = NoteType(rawValue: processed.type.lowercased()) ?? .note
        return Note(rawText: rawText, type: noteType, tasks: processed.tasks,
                    tags: processed.tags, summary: processed.summary)
    }

    // MARK: - AI Enhancement

    public func enhanceNote(rawText: String, mode: EnhancementMode) async throws -> String {
        if useMock {
            try? await Task.sleep(nanoseconds: 900_000_000)
            // Mock: prefix with mode label so it's visibly different
            switch mode {
            case .clarity:
                return rawText.components(separatedBy: ". ").first.map { $0 + "." } ?? rawText
            case .expand:
                return "\(rawText) This connects to a broader pattern worth exploring further, with implications that surface once the core idea is given room to breathe."
            case .sharpen:
                return rawText.components(separatedBy: CharacterSet.newlines).map { "→ \($0.trimmingCharacters(in: .whitespaces))" }.joined(separator: "\n")
            case .reframe:
                return "Here's a clearer frame: \(rawText.lowercased()). The next concrete step is to decide what this actually requires."
            }
        }
        return try await apiEnhance(rawText: rawText, mode: mode)
    }

    // MARK: - Related notes

    public func findRelatedNoteIDs(for note: Note, from allNotes: [Note]) async -> [UUID] {
        if useMock {
            let noteWords = Set(note.rawText.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 3 })
            let noteTagSet = Set(note.tags)

            let scored: [(Note, Int)] = allNotes
                .filter { $0.id != note.id && !$0.isArchived }
                .map { candidate in
                    let cWords = Set(candidate.rawText.lowercased()
                        .components(separatedBy: .whitespacesAndNewlines)
                        .filter { $0.count > 3 })
                    let tagScore = Set(candidate.tags).intersection(noteTagSet).count * 3
                    let wordScore = cWords.intersection(noteWords).count
                    return (candidate, tagScore + wordScore)
                }
                .filter { $0.1 > 0 }
                .sorted { $0.1 > $1.1 }

            return Array(scored.prefix(3).map { $0.0.id })
        }
        // Real implementation would make a Claude API call
        return []
    }

    // MARK: - Mock processing

    private func mockProcess(rawText: String) async -> ProcessedNoteResponse {
        try? await Task.sleep(nanoseconds: 400_000_000)
        let text = rawText.lowercased()
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return ProcessedNoteResponse(
            type: classifyType(text: text).rawValue,
            tasks: extractTasks(from: rawText),
            tags: generateTags(from: text, words: words),
            summary: generateSummary(from: rawText)
        )
    }

    private func classifyType(text: String) -> NoteType {
        if text.contains("http://") || text.contains("https://") || text.contains("www.") { return .link }
        let taskKeywords = ["todo", "need to", "must", "should", "have to", "remember to",
                            "don't forget", "buy", "call", "email", "send", "finish",
                            "complete", "schedule", "book", "pick up", "remind"]
        if taskKeywords.contains(where: { text.contains($0) }) { return .task }
        let ideaKeywords = ["idea", "what if", "maybe", "could", "might", "imagine",
                            "concept", "thought", "wondering", "consider", "possibly"]
        if ideaKeywords.contains(where: { text.contains($0) }) { return .idea }
        return .note
    }

    private func extractTasks(from text: String) -> [String] {
        var tasks: [String] = []
        for line in text.components(separatedBy: CharacterSet.newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") ||
               trimmed.hasPrefix("*") || trimmed.first?.isNumber == true {
                let task = trimmed
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-•*0123456789.) "))
                    .trimmingCharacters(in: .whitespaces)
                if !task.isEmpty { tasks.append(task) }
            }
        }
        if tasks.isEmpty && classifyType(text: text.lowercased()) == .task {
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty { tasks.append(cleaned) }
        }
        return tasks
    }

    private func generateTags(from text: String, words: [String]) -> [String] {
        var tags: Set<String> = []
        let categoryMap: [String: [String]] = [
            "work":     ["meeting", "deadline", "project", "client", "boss", "office", "report"],
            "personal": ["home", "family", "friend", "birthday", "vacation", "weekend"],
            "shopping": ["buy", "store", "order", "amazon", "grocery", "shop"],
            "health":   ["doctor", "gym", "exercise", "medicine", "appointment", "workout"],
            "finance":  ["pay", "bill", "money", "bank", "budget", "invoice", "expense"],
            "travel":   ["flight", "hotel", "trip", "booking", "airport", "vacation"],
            "learning": ["read", "book", "course", "learn", "study", "tutorial"]
        ]
        for (tag, keywords) in categoryMap {
            if keywords.contains(where: { text.contains($0) }) { tags.insert(tag) }
        }
        if text.contains("today") || text.contains("now") || text.contains("asap") { tags.insert("urgent") }
        if text.contains("tomorrow") || text.contains("next week") || text.contains("later") { tags.insert("upcoming") }
        return Array(tags.prefix(4))
    }

    private func generateSummary(from text: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count <= 60 { return cleaned }
        if let end = cleaned.firstIndex(where: { $0 == "." || $0 == "!" || $0 == "?" }) {
            let sentence = String(cleaned[...end])
            if sentence.count <= 80 { return sentence }
        }
        let index = cleaned.index(cleaned.startIndex, offsetBy: min(57, cleaned.count))
        return String(cleaned[..<index]).trimmingCharacters(in: .whitespaces) + "..."
    }

    // MARK: - API processing

    private func apiProcess(rawText: String) async throws -> ProcessedNoteResponse {
        guard !apiKey.isEmpty else { throw NoteProcessorError.missingAPIKey }
        guard let url = URL(string: baseURL) else { throw NoteProcessorError.invalidURL }

        let systemPrompt = """
        You are a note classification and extraction assistant. Analyze the user's input and return a JSON object with exactly these fields:
        - type: one of "task", "idea", "note", or "link"
        - tasks: array of extracted action items (empty array if none)
        - tags: array of 1-5 relevant lowercase tags (no # symbol)
        - summary: one sentence summary of the content
        Respond ONLY with valid JSON, no markdown formatting or explanation.
        """
        let body: [String: Any] = [
            "model": kClaudeModelID,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [["role": "user", "content": rawText]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NoteProcessorError.apiError(msg)
        }
        return try parseClassifyResponse(data)
    }

    private func apiEnhance(rawText: String, mode: EnhancementMode) async throws -> String {
        guard !apiKey.isEmpty else { throw NoteProcessorError.missingAPIKey }
        guard let url = URL(string: baseURL) else { throw NoteProcessorError.invalidURL }

        let body: [String: Any] = [
            "model": kClaudeModelID,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": mode.prompt + rawText]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NoteProcessorError.invalidResponse
        }

        struct Resp: Codable {
            struct Content: Codable { let type: String; let text: String? }
            let content: [Content]
        }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        guard let text = resp.content.first(where: { $0.type == "text" })?.text else {
            throw NoteProcessorError.invalidResponse
        }
        return text
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw NoteProcessorError.networkError(error)
        }
    }

    private func parseClassifyResponse(_ data: Data) throws -> ProcessedNoteResponse {
        struct AnthropicResponse: Codable {
            struct Content: Codable { let type: String; let text: String? }
            let content: [Content]
        }
        let anthropicResponse: AnthropicResponse
        do {
            anthropicResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        } catch {
            throw NoteProcessorError.decodingError(error)
        }
        guard let textContent = anthropicResponse.content.first(where: { $0.type == "text" }),
              let rawText = textContent.text else {
            throw NoteProcessorError.invalidResponse
        }
        // Extract the JSON object by scanning for the outermost { } — robust against markdown fences
        guard let start = rawText.firstIndex(of: "{"),
              let end = rawText.lastIndex(of: "}"),
              start <= end else {
            throw NoteProcessorError.invalidResponse
        }
        let jsonText = String(rawText[start...end])
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw NoteProcessorError.invalidResponse
        }
        do {
            return try JSONDecoder().decode(ProcessedNoteResponse.self, from: jsonData)
        } catch {
            throw NoteProcessorError.decodingError(error)
        }
    }
}
