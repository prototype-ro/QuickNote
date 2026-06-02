// ShareViewController.swift — Share Extension entry point

import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.01)
        extractContent()
    }

    // MARK: - Content extraction

    private func extractContent() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            cancel(); return
        }

        let sharedTitle = item.attributedTitle?.string ?? item.attributedContentText?.string
        let attachments = item.attachments ?? []
        let urlType  = UTType.url.identifier
        let textType = UTType.plainText.identifier

        if let att = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
            att.loadItem(forTypeIdentifier: urlType) { [weak self] data, _ in
                let str = (data as? URL)?.absoluteString ?? (data as? String)
                DispatchQueue.main.async {
                    if let str { self?.showCard(content: str, pageTitle: sharedTitle) }
                    else { self?.cancel() }
                }
            }
        } else if let att = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(textType) }) {
            att.loadItem(forTypeIdentifier: textType) { [weak self] data, _ in
                let str = data as? String
                DispatchQueue.main.async {
                    if let str { self?.showCard(content: str, pageTitle: sharedTitle) }
                    else { self?.cancel() }
                }
            }
        } else {
            cancel()
        }
    }

    // MARK: - Show SwiftUI card

    private func showCard(content: String, pageTitle: String?) {
        let isURL = Self.detectURL(in: content)
        let host = isURL ? Self.host(from: content) : ""
        let displayTitle = pageTitle ?? (isURL ? host : String(content.prefix(60)))

        let card = ShareView(
            urlString: content,
            title: displayTitle,
            host: isURL ? host : "",
            onSave: { [weak self] contextNote in
                self?.save(content: content, title: displayTitle, host: host,
                           isURL: isURL, contextNote: contextNote)
            },
            onCancel: { [weak self] in self?.cancel() }
        )

        let hosting = UIHostingController(rootView: card)
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosting.didMove(toParent: self)
    }

    // MARK: - Persist & dismiss

    private func save(content: String, title: String, host: String,
                      isURL: Bool, contextNote: String) {
        let groupID = "group.com.prototype.QuickNote"
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        let fileURL = container.appendingPathComponent("pendingLinks.json")
        var items: [[String: String]] = []
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([[String: String]].self, from: data) {
            items = decoded
        }

        var item: [String: String] = [
            "content": content,
            "title": title,
            "host": host,
            "type": isURL ? "link" : "note"
        ]
        if !contextNote.isEmpty { item["note"] = contextNote }
        items.append(item)

        if let encoded = try? JSONEncoder().encode(items) {
            try? encoded.write(to: fileURL, options: .atomic)
        }

        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func cancel() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    // MARK: - URL detection (NSDataDetector — not regex)

    static func detectURL(in text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        let nsText = trimmed as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = detector.firstMatch(in: trimmed, range: range) else { return false }
        let matchedStr = nsText.substring(with: match.range)
        return match.range.length >= Int(Double(nsText.length) * 0.85) && !matchedStr.contains("@")
    }

    static func host(from url: String) -> String {
        guard let parsed = URL(string: url.hasPrefix("http") ? url : "https://\(url)"),
              let h = parsed.host else { return url }
        return h.replacingOccurrences(of: "www.", with: "")
    }
}
