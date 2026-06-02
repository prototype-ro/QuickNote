// WidgetBridge.swift — keeps the widget's shared snapshot in sync with the corpus.

import Foundation
import WidgetKit

/// Writes a fresh `WidgetSnapshot` to the app group and reloads widget timelines
/// whenever the note corpus changes. The widget reads only this snapshot.
public enum WidgetBridge {

    /// Rebuilds the snapshot from the current notes and pushes it to the widget.
    /// Cheap; safe to call on every corpus change.
    @MainActor
    public static func update(from notes: [Note]) {
        let active = notes.filter { !$0.isArchived }
        let sorted = active.sorted { $0.createdAt > $1.createdAt }
        let latest = sorted.first

        let snapshot = WidgetSnapshot(
            latestText: latest?.embeddingSource ?? "",
            latestType: latest?.type.rawValue ?? "note",
            count: active.count,
            resurfacedText: resurfaced(in: active)?.embeddingSource
        )
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// One older reflective note closest to the last 7 days' captures — same
    /// logic as the digest, surfaced on the widget.
    private static func resurfaced(in notes: [Note]) -> Note? {
        let now = Date()
        let weekAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let twoWeeksAgo = now.addingTimeInterval(-14 * 24 * 60 * 60)
        let reflective: (Note) -> Bool = { $0.type == .note || $0.type == .idea }

        let recentAll = notes.filter { reflective($0) && $0.createdAt >= weekAgo }
        let lang = Dictionary(grouping: recentAll, by: { $0.langCode })
            .max { $0.value.count < $1.value.count }?.key ?? ""
        let recent = recentAll.filter { $0.langCode == lang }
        let centroid = SemanticIndex.centroid(of: recent.map { $0.embedding })
        guard !centroid.isEmpty else { return nil }

        let older = notes.filter { reflective($0) && $0.createdAt < twoWeeksAgo && $0.langCode == lang }
        return SemanticIndex.bestMatch(to: centroid, among: older, threshold: 0.45)?.note
    }
}
