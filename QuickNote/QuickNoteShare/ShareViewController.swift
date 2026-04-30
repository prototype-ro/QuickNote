// ShareViewController.swift — Share Extension entry point

import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Nearly transparent so the system dim shows through behind the card
        view.backgroundColor = UIColor.black.withAlphaComponent(0.01)
        extractURL()
    }

    // MARK: - URL extraction

    private func extractURL() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            cancel(); return
        }

        // Some apps surface the page title here
        let sharedTitle = item.attributedTitle?.string ?? item.attributedContentText?.string

        let attachments = item.attachments ?? []
        let urlType  = UTType.url.identifier
        let textType = UTType.plainText.identifier

        if let att = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
            att.loadItem(forTypeIdentifier: urlType) { [weak self] data, _ in
                let str = (data as? URL)?.absoluteString ?? (data as? String)
                DispatchQueue.main.async {
                    if let str { self?.showCard(urlString: str, pageTitle: sharedTitle) }
                    else { self?.cancel() }
                }
            }
        } else if let att = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(textType) }) {
            att.loadItem(forTypeIdentifier: textType) { [weak self] data, _ in
                let str = data as? String
                DispatchQueue.main.async {
                    if let str { self?.showCard(urlString: str, pageTitle: sharedTitle) }
                    else { self?.cancel() }
                }
            }
        } else {
            cancel()
        }
    }

    // MARK: - Show SwiftUI card

    private func showCard(urlString: String, pageTitle: String?) {
        let host = Self.host(from: urlString)
        let card = ShareView(
            urlString: urlString,
            title: pageTitle ?? host,
            host: host,
            onSave: { [weak self] in self?.save(urlString: urlString, title: pageTitle ?? host, host: host) },
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

    private func save(urlString: String, title: String, host: String) {
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
        items.append(["url": urlString, "title": title, "host": host])
        if let encoded = try? JSONEncoder().encode(items) {
            try? encoded.write(to: fileURL, options: .atomic)
        }

        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "QuickNoteShare", code: 0))
    }

    static func host(from url: String) -> String {
        guard let parsed = URL(string: url.hasPrefix("http") ? url : "https://\(url)"),
              let h = parsed.host else { return url }
        return h.replacingOccurrences(of: "www.", with: "")
    }
}
