import Foundation

// MARK: - Constants

public let kClaudeModelID = "claude-haiku-4-5-20251001"
public let kUseMockProcessor = false

// MARK: - Enhancement modes

public enum EnhancementMode: String, CaseIterable {
    /// One smart enhancer that infers intent from the content — fixes spelling,
    /// grammar, and word choice; structures brain-dumps (groceries, tasks) into
    /// clean lists; tightens prose. Replaces the former clarity/expand/sharpen/
    /// reframe modes. Raw value kept stable for migration of `note.enhancementMode`.
    case enhance

    var label: String { "Enhance" }

    var systemPrompt: String {
        """
        You are a writing assistant. Improve the user's note while preserving \
        their meaning and voice. Infer intent from the content:
        - Fix spelling, grammar, punctuation, and awkward word choice.
        - If it reads as a list or brain-dump (e.g. groceries, errands, tasks), \
        organize it into a clean, logically grouped list — one item per line, no \
        bullet characters or numbering.
        - If it is prose, tighten it for clarity and flow.
        Do not add new information, opinions, or facts the user did not write. Do \
        not use markdown headers, bold, or emphasis. Return only the improved text, \
        nothing else.
        """
    }
}

// MARK: - API response types

public struct ProcessedNoteResponse: Codable {
    public let type: String
    public let tasks: [String]
    public let tags: [String]
    public let summary: String
    /// A scheduleable event extracted from the note, when one is clearly present.
    public var event: DetectedEvent?
    /// Media (movie) detected for enrichment, when clearly present.
    public var media: DetectedMedia?

    public init(type: String, tasks: [String], tags: [String], summary: String,
                event: DetectedEvent? = nil, media: DetectedMedia? = nil) {
        self.type = type
        self.tasks = tasks
        self.tags = tags
        self.summary = summary
        self.event = event
        self.media = media
    }
}

/// A calendar-able event the model found in free text. `date` is an ISO-ish
/// local datetime string ("2026-09-19T09:00:00") or date-only ("2026-09-19").
public struct DetectedEvent: Codable {
    public let title: String
    public let date: String
    public let hasTime: Bool
}

/// A media item the model found in free text (currently movies). `query` is a
/// search string for TMDB, e.g. "Obsession".
public struct DetectedMedia: Codable {
    public let kind: String     // "movie"
    public let query: String
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

    public func createNote(from rawText: String) async -> Note {
        let processed: ProcessedNoteResponse
        do {
            processed = try await process(rawText: rawText)
        } catch {
            // Capture must never lose a thought. If the API is unreachable,
            // unconfigured, or returns garbage, fall back to local classification.
            // rawText is the user's exact words and is always preserved.
            processed = localClassify(rawText: rawText)
        }
        let noteType = NoteType(rawValue: processed.type.lowercased()) ?? .note
        let note = Note(rawText: rawText, type: noteType, tasks: processed.tasks,
                        tags: processed.tags, summary: processed.summary)
        if let event = processed.event, let date = Self.parseEventDate(event.date) {
            note.eventTitle = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            note.eventDate = date
            note.eventHasTime = event.hasTime
            if note.dueDate == nil { note.dueDate = date }
        }
        if let media = processed.media, media.kind == "movie" {
            note.media = await TMDBService.shared.lookup(query: media.query)
        }
        return note
    }

    /// Parses the model's local datetime string into a `Date`, accepting both
    /// "yyyy-MM-dd'T'HH:mm:ss" and date-only "yyyy-MM-dd". Interpreted in the
    /// device's current time zone (the prompt resolves relative days locally).
    static func parseEventDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd"] {
            f.dateFormat = format
            if let d = f.date(from: trimmed) { return d }
        }
        return nil
    }

    // MARK: - AI Enhancement

    public func enhanceNote(rawText: String, mode: EnhancementMode) async throws -> String {
        if useMock {
            try? await Task.sleep(nanoseconds: 900_000_000)
            // Mock: lightly clean whitespace so the result is visibly different.
            return rawText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
        return try await apiEnhance(rawText: rawText, mode: mode)
    }

    // MARK: - Related notes

    public func findRelated(for note: Note, allNotes: [Note]) async throws -> [UUID] {
        let candidates = allNotes.filter { $0.id != note.id && !$0.isArchived }.prefix(20)
        guard !candidates.isEmpty else { return [] }

        if useMock {
            let noteWords = Set((note.displayText ?? note.rawText).lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 3 })
            let noteTagSet = Set(note.tags)
            let scored: [(Note, Int)] = candidates.map { c in
                let cWords = Set((c.displayText ?? c.rawText).lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { $0.count > 3 })
                let tagScore = Set(c.tags).intersection(noteTagSet).count * 3
                let wordScore = cWords.intersection(noteWords).count
                return (c, tagScore + wordScore)
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            return Array(scored.prefix(3).map { $0.0.id })
        }

        guard !apiKey.isEmpty else { return [] }
        guard let url = URL(string: baseURL) else { return [] }

        let systemPrompt = "You are a semantic similarity engine. Given a source note and candidate notes, return a JSON array of the UUIDs of the 2-3 most semantically related candidates. If no candidates are strongly related, return an empty array. Respond ONLY with a valid JSON array of UUID strings, no other text."
        let candidateLines = candidates
            .map { "ID: \($0.id.uuidString)\nText: \($0.displayText ?? $0.rawText)" }
            .joined(separator: "\n\n")
        let userMessage = "Source note:\n\(note.displayText ?? note.rawText)\n\nCandidates:\n\(candidateLines)"

        let body: [String: Any] = [
            "model": kClaudeModelID,
            "max_tokens": 256,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userMessage]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        guard let body = try? JSONSerialization.data(withJSONObject: body) else { return [] }
        request.httpBody = body

        guard let (data, response) = try? await performRequest(request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return [] }

        struct Resp: Codable {
            struct Content: Codable { let type: String; let text: String? }
            let content: [Content]
        }
        guard let resp = try? JSONDecoder().decode(Resp.self, from: data),
              let text = resp.content.first(where: { $0.type == "text" })?.text else { return [] }

        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]"),
              start <= end else { return [] }
        let jsonText = String(text[start...end])
        guard let jsonData = jsonText.data(using: .utf8),
              let uuidStrings = try? JSONDecoder().decode([String].self, from: jsonData) else { return [] }

        return uuidStrings.compactMap { UUID(uuidString: $0) }
    }

    // MARK: - Recall synthesis

    /// Stitches a one- or two-sentence answer to `query` using ONLY the user's
    /// own `snippets`. The user's notes stay primary; this is connective tissue.
    /// Only the provided snippets are sent to the API — nothing else from the corpus.
    public func synthesize(query: String, snippets: [String]) async throws -> String {
        let trimmedSnippets = snippets.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !trimmedSnippets.isEmpty else { return "" }

        if useMock {
            try? await Task.sleep(nanoseconds: 700_000_000)
            return "Across these notes, a thread runs through what you wrote about \(query.lowercased())."
        }

        guard !apiKey.isEmpty else { throw NoteProcessorError.missingAPIKey }
        guard let url = URL(string: baseURL) else { throw NoteProcessorError.invalidURL }

        let systemPrompt = """
        You are the user's own memory speaking back to them. Answer their question \
        using ONLY the notes provided — never invent facts or add outside knowledge. \
        Write one or two sentences, in a calm, plain voice as if continuing the user's \
        own thought. Do not list the notes; weave them. If the notes don't address the \
        question, say so briefly. Return only the answer, no preamble.
        """
        let notesBlock = trimmedSnippets.enumerated()
            .map { "Note \($0.offset + 1): \($0.element)" }
            .joined(separator: "\n\n")
        let userMessage = "Question: \(query)\n\nMy notes:\n\(notesBlock)"

        let body: [String: Any] = [
            "model": kClaudeModelID,
            "max_tokens": 256,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userMessage]]
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
        return Self.stripMarkdown(text)
    }

    // MARK: - Mock processing

    private func mockProcess(rawText: String) async -> ProcessedNoteResponse {
        try? await Task.sleep(nanoseconds: 400_000_000)
        return localClassify(rawText: rawText)
    }

    /// Offline, on-device note classification. Pure-Swift heuristics, no network.
    /// Used as the guaranteed fallback so a capture is never lost when the API
    /// is unreachable, unconfigured, or returns an unparseable response.
    public func localClassify(rawText: String) -> ProcessedNoteResponse {
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

        let now = Date()
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "EEEE, yyyy-MM-dd HH:mm"
        let nowString = dateFmt.string(from: now)

        let systemPrompt = """
        You are a note classification and extraction assistant. The current local date and time is \(nowString). Analyze the user's input and return a JSON object with exactly these fields:
        - type: one of "task", "idea", "note", or "link"
        - tasks: array of extracted action items (empty array if none)
        - tags: array of 1-5 relevant lowercase tags (no # symbol)
        - summary: one sentence summary of the content
        - event: a calendar event IF the note clearly describes something scheduleable with a specific date or day (e.g. "Anna's birthday 19th Sept 9am", "dentist tuesday 3pm", "movie saturday"). Otherwise null. When present, event is an object with:
            - title: a short event name (e.g. "Anna's birthday"), excluding any to-do part
            - date: the resolved local datetime as "yyyy-MM-dd'T'HH:mm:ss" when a time is given, or date-only "yyyy-MM-dd" when no time is given. Resolve relative days ("saturday", "tomorrow") against the current date above, choosing the next future occurrence.
            - hasTime: true if a specific time was given, false otherwise
          Any imperative to-do attached to the event (e.g. "buy gift") must ALSO appear in the tasks array.
        - media: an object IF the note expresses intent to watch/see a specific named MOVIE (e.g. "watch obsession saturday", "see the new dune movie"). Otherwise null. When present: { "kind": "movie", "query": "<the movie's title only, no extra words>" }. Only set this for movies, not music, articles, or generic links.
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
            "system": mode.systemPrompt,
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
        return Self.stripMarkdown(text)
    }

    // MARK: - Markdown stripping

    static func stripMarkdown(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: #"(?m)^#{1,6} "#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "**", with: "")
        s = s.replacingOccurrences(of: "__", with: "")
        s = s.replacingOccurrences(of: #"(?m)^[\-\•\*]\s+"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "`", with: "")
        s = s.replacingOccurrences(of: #"(?m)^\d+\.\s+"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
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
            let raw = try JSONDecoder().decode(ProcessedNoteResponse.self, from: jsonData)
            return ProcessedNoteResponse(
                type: raw.type,
                tasks: raw.tasks.map { Self.stripMarkdown($0) },
                tags: raw.tags,
                summary: Self.stripMarkdown(raw.summary),
                event: raw.event,
                media: raw.media
            )
        } catch {
            throw NoteProcessorError.decodingError(error)
        }
    }
}
