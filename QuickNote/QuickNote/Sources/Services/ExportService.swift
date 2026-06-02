// ExportService.swift — turns the corpus into a portable Markdown document.
// Gives users a way to get their thoughts OUT — no lock-in, a manual backup.

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// A Markdown rendering of the user's notes, shareable via `ShareLink`.
struct NotesExport: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { export in
            Data(export.text.utf8)
        }
        .suggestedFileName("QuickNote-export.md")
    }
}

enum ExportService {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    /// Renders all non-archived notes (newest first) as Markdown.
    static func markdown(from notes: [Note]) -> String {
        let sorted = notes.filter { !$0.isArchived }.sorted { $0.createdAt > $1.createdAt }
        var out = "# QuickNote export\n\n_\(sorted.count) thoughts · \(dateFormatter.string(from: Date()))_\n\n"
        for note in sorted {
            out += "## \(note.type.rawValue.uppercased()) — \(dateFormatter.string(from: note.createdAt))\n\n"
            out += (note.displayText ?? note.rawText) + "\n\n"
            if !note.tasks.isEmpty {
                out += note.tasks.map { "- [ ] \($0)" }.joined(separator: "\n") + "\n\n"
            }
            if !note.tags.isEmpty {
                out += note.tags.map { "#\($0)" }.joined(separator: " ") + "\n\n"
            }
            out += "---\n\n"
        }
        return out
    }

    static func document(from notes: [Note]) -> NotesExport {
        NotesExport(text: markdown(from: notes))
    }
}
