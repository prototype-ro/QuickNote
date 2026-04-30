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
        isArchived: Bool = false
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
    }
}
