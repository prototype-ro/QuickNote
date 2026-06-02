import Foundation
import SwiftData

public enum NoteType: String, Codable, CaseIterable {
    case task, idea, note, link, digest

    public var iconName: String {
        switch self {
        case .task:   return "checkmark.circle"
        case .idea:   return "lightbulb"
        case .note:   return "note.text"
        case .link:   return "link"
        case .digest: return "calendar"
        }
    }

    public var displayName: String { rawValue.uppercased() }
}

@Model
public final class Note {
    public var id: UUID
    /// Original user input — never modified after creation
    public var rawText: String
    /// AI-enhanced text; nil means fall back to rawText for display
    public var displayText: String?
    public var type: NoteType
    public var tasks: [String]
    public var tags: [String]
    public var summary: String
    /// Records the last applied AI enhancer mode
    public var enhancementMode: String?
    public var createdAt: Date
    public var isArchived: Bool
    /// Completion state parallel to `tasks` (same index). Inline default for migration.
    public var taskDone: [Bool] = []
    /// Optional due date for task-type notes. Optional → migration-safe.
    public var dueDate: Date? = nil
    /// On-device semantic embedding of the note's text. Empty until computed.
    /// Powers contextual resurfacing (echo at capture, recall, digest).
    /// Inline default `= []` is required for SwiftData lightweight migration of
    /// existing stores — without it, adding this attribute traps at container init.
    public var embedding: [Double] = []
    /// Language code (e.g. "en", "pt") of the model that produced `embedding`.
    /// Vectors are only compared within the same language. Inline default for migration.
    public var langCode: String = ""

    public init(
        id: UUID = UUID(),
        rawText: String,
        displayText: String? = nil,
        type: NoteType = .note,
        tasks: [String] = [],
        tags: [String] = [],
        summary: String = "",
        enhancementMode: String? = nil,
        createdAt: Date = Date(),
        isArchived: Bool = false,
        embedding: [Double] = []
    ) {
        self.id = id
        self.rawText = rawText
        self.displayText = displayText
        self.type = type
        self.tasks = tasks
        self.tags = tags
        self.summary = summary
        self.enhancementMode = enhancementMode
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.embedding = embedding
    }

    /// Full text for DISPLAY — the enhanced/edited text if present, else raw.
    public var embeddingSource: String { displayText ?? rawText }

    /// Text fed to the EMBEDDING model. For long ("developed") notes the full
    /// document makes a weak sentence vector, so we embed the summary (or the
    /// head) instead — keeping echo/recall coherent. Short notes embed as-is.
    public var embeddingInput: String {
        let text = displayText ?? rawText
        guard text.count > 400 else { return text }
        return summary.isEmpty ? String(text.prefix(400)) : summary
    }

    /// Whether this note has grown into long-form ("developed") content.
    public var isLongForm: Bool { (displayText ?? rawText).count > 280 }

    /// Whether the task at `index` is complete (safe for migrated notes whose
    /// `taskDone` array is empty or shorter than `tasks`).
    public func isTaskDone(_ index: Int) -> Bool {
        index >= 0 && index < taskDone.count ? taskDone[index] : false
    }

    /// Sets completion for the task at `index`, growing `taskDone` to match `tasks`.
    public func setTask(_ index: Int, done: Bool) {
        while taskDone.count < tasks.count { taskDone.append(false) }
        guard index >= 0 && index < taskDone.count else { return }
        taskDone[index] = done
    }

    /// Count of completed tasks.
    public var completedTaskCount: Int {
        tasks.indices.filter { isTaskDone($0) }.count
    }
}
