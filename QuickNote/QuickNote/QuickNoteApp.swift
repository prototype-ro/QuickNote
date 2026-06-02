// QuickNoteApp.swift

import SwiftUI
import SwiftData

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }
}

@main
struct QuickNoteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    let container: ModelContainer = {
        let schema = Schema([Note.self, Link.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Migration/open failed. A notes app must NEVER silently destroy the
            // user's data — preserve the old store as a recoverable backup BEFORE
            // recreating, so nothing is lost irreversibly.
            let storeURL = config.url
            Self.backupStore(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("ModelContainer could not be created: \(error)")
            }
        }
    }()

    /// Copies the store (and its -wal/-shm siblings) to a timestamped backup folder
    /// so a failed migration is recoverable instead of a permanent loss.
    private static func backupStore(at storeURL: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupDir = storeURL.deletingLastPathComponent()
            .appendingPathComponent("Backups/\(stamp)", isDirectory: true)
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        for url in [storeURL,
                    storeURL.appendingPathExtension("wal"),
                    storeURL.appendingPathExtension("shm")] {
            guard fm.fileExists(atPath: url.path) else { continue }
            try? fm.copyItem(at: url, to: backupDir.appendingPathComponent(url.lastPathComponent))
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                importPendingLinks()
            }
        }
    }

    // MARK: - Import links saved by the Share Extension

    private func importPendingLinks() {
        let groupID = "group.com.prototype.QuickNote"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return }

        let fileURL = containerURL.appendingPathComponent("pendingLinks.json")
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([[String: String]].self, from: data),
              !items.isEmpty else { return }

        let ctx = container.mainContext
        let processor = NoteProcessor()
        var inserted: [Link] = []
        for item in items {
            guard let content = item["content"] else { continue }
            let type = item["type"] ?? "link"
            let host = item["host"] ?? extractHost(from: content)
            let title = item["title"] ?? host

            if type == "link" {
                let kind = LinkKind.detect(from: content)
                let link = Link(urlString: content, title: title, host: host, kind: kind)
                let contextNote = item["note"] ?? ""
                if !contextNote.isEmpty {
                    link.userNote = contextNote
                    // Also surface the annotation as a Note in the Mind inbox
                    // so the user's thought isn't buried in Library only.
                    let processed = processor.localClassify(rawText: contextNote)
                    let noteType = NoteType(rawValue: processed.type.lowercased()) ?? .note
                    let note = Note(rawText: contextNote, type: noteType,
                                   tasks: processed.tasks, tags: processed.tags,
                                   summary: processed.summary)
                    ctx.insert(note)
                }
                ctx.insert(link)
                inserted.append(link)
            } else if type == "note", !content.isEmpty {
                // Plain text shared from another app — goes directly to Mind inbox.
                let processed = processor.localClassify(rawText: content)
                let noteType = NoteType(rawValue: processed.type.lowercased()) ?? .note
                let note = Note(rawText: content, type: noteType,
                               tasks: processed.tasks, tags: processed.tags,
                               summary: processed.summary)
                ctx.insert(note)
            }
        }
        try? ctx.save()
        try? FileManager.default.removeItem(at: fileURL)

        // Fetch real metadata in the background for each imported link
        for link in inserted {
            let urlString = link.urlString
            let kind = link.kind
            Task {
                let meta = await LinkMetadataService.shared.fetch(urlString: urlString, kind: kind)
                await MainActor.run {
                    if let title = meta.title, !title.isEmpty { link.title = title }
                    if let thumb = meta.thumbnailURLString { link.thumbnailURL = thumb }
                    if let author = meta.author { link.author = author }
                    try? ctx.save()
                }
            }
        }
    }

    private func extractHost(from url: String) -> String {
        guard let parsed = URL(string: url.hasPrefix("http") ? url : "https://\(url)"),
              let host = parsed.host else { return url }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
