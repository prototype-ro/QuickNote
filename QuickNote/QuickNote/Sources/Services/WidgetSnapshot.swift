// WidgetSnapshot.swift — the small payload the app shares with the widget.
//
// IMPORTANT: add this file to BOTH target memberships (QuickNote app + QuickNoteWidget).
// The app writes the snapshot on note changes; the widget reads it. Sharing happens
// through the app group's UserDefaults — the SwiftData store is never read by the widget.

import Foundation

/// A glanceable summary of the user's mind, written by the app and read by the widget.
public struct WidgetSnapshot: Codable {
    public var latestText: String
    public var latestType: String
    public var count: Int
    /// One older note the engine chose to resurface, if any.
    public var resurfacedText: String?

    public init(latestText: String, latestType: String, count: Int, resurfacedText: String? = nil) {
        self.latestText = latestText
        self.latestType = latestType
        self.count = count
        self.resurfacedText = resurfacedText
    }

    /// Shown before the app has written anything.
    public static let empty = WidgetSnapshot(latestText: "", latestType: "note", count: 0)

    // MARK: - App group storage

    public static let appGroupID = "group.com.prototype.QuickNote"
    private static let storageKey = "widgetSnapshot"

    /// Reads the current snapshot from the shared app group, or `.empty`.
    public static func load() -> WidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    /// Writes this snapshot to the shared app group.
    public func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

/// Deep-link routes the widget asks the app to open.
public enum WidgetRoute {
    public static let scheme = "quicknote"
    public static let capture = URL(string: "quicknote://capture")
    public static let inbox = URL(string: "quicknote://inbox")
}
