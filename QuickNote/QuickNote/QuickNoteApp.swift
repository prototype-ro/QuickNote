// QuickNoteApp.swift

import SwiftUI
import SwiftData

@main
struct QuickNoteApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let container: ModelContainer = {
        let schema = Schema([Note.self, Link.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Migration failed — wipe the store and start clean rather than crashing
            let storeURL = config.url
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
        var inserted: [Link] = []
        for item in items {
            guard let urlString = item["url"] else { continue }
            let host = item["host"] ?? extractHost(from: urlString)
            let title = item["title"] ?? host
            let kind = LinkKind.detect(from: urlString)
            let link = Link(urlString: urlString, title: title, host: host, kind: kind)
            ctx.insert(link)
            inserted.append(link)
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
