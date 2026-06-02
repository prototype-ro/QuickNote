// ShareViewController.swift — Share Extension entry point (programmatic, no storyboard)
//
// Launched via NSExtensionPrincipalClass (set in Info.plist). Extracts a shared
// URL or text, presents a SwiftUI confirmation card, and on save writes the item
// to the shared App Group queue. The main app drains that queue into the Library.

import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    private static let appGroupID = "group.com.prototype.QuickNote"
    private static let queueFile = "pendingLinks.json"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        extractContent()
    }

    // MARK: - Content extraction

    private func extractContent() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            close(); return
        }

        let pageTitle = item.attributedTitle?.string ?? item.attributedContentText?.string
        let attachments = item.attachments ?? []
        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier

        if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] data, _ in
                let str = (data as? URL)?.absoluteString ?? (data as? String)
                DispatchQueue.main.async {
                    if let str, !str.isEmpty { self?.present(content: str, pageTitle: pageTitle) }
                    else { self?.close() }
                }
            }
        } else if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(textType) }) {
            provider.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] data, _ in
                let str = data as? String
                DispatchQueue.main.async {
                    if let str, !str.isEmpty { self?.present(content: str, pageTitle: pageTitle) }
                    else { self?.close() }
                }
            }
        } else {
            close()
        }
    }

    // MARK: - SwiftUI card

    private func present(content: String, pageTitle: String?) {
        let isURL = Self.isURL(content)
        let host = isURL ? Self.host(from: content) : ""
        let title = pageTitle ?? (isURL ? host : String(content.prefix(60)))

        let card = ShareView(
            urlString: content,
            title: title,
            host: host,
            onSave: { [weak self] note in
                self?.enqueue(content: content, title: title, host: host, isURL: isURL, note: note)
                self?.close()
            },
            onCancel: { [weak self] in self?.close() }
        )

        let hosting = UIHostingController(rootView: card)
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosting.didMove(toParent: self)
    }

    // MARK: - Persist to App Group queue

    private func enqueue(content: String, title: String, host: String, isURL: Bool, note: String) {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) else { return }

        let fileURL = container.appendingPathComponent(Self.queueFile)
        var items: [[String: String]] = []
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([[String: String]].self, from: data) {
            items = decoded
        }

        var item: [String: String] = [
            "content": content,
            "title": title,
            "host": host,
            "type": isURL ? "link" : "note",
        ]
        if !note.isEmpty { item["note"] = note }
        items.append(item)

        if let encoded = try? JSONEncoder().encode(items) {
            try? encoded.write(to: fileURL, options: .atomic)
        }
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    // MARK: - URL helpers (NSDataDetector, not regex)

    static func isURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        let ns = trimmed as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = detector.firstMatch(in: trimmed, range: range) else { return false }
        let matched = ns.substring(with: match.range)
        return match.range.length >= Int(Double(ns.length) * 0.85) && !matched.contains("@")
    }

    static func host(from url: String) -> String {
        guard let parsed = URL(string: url.hasPrefix("http") ? url : "https://\(url)"),
              let h = parsed.host else { return url }
        return h.replacingOccurrences(of: "www.", with: "")
    }
}
