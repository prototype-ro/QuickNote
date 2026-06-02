// Link.swift — SwiftData model for captured URLs (Library shelf)

import Foundation
import SwiftData

public enum LinkKind: String, Codable {
    case youtube, tiktok, instagram, spotify, article, bare

    public var platformLabel: String? {
        switch self {
        case .youtube:   return "YouTube"
        case .tiktok:    return "TikTok"
        case .instagram: return "Instagram"
        case .spotify:   return "Spotify"
        case .article, .bare: return nil
        }
    }

    public static func detect(from url: String) -> LinkKind {
        let lower = url.lowercased()
        if lower.contains("youtube") || lower.contains("youtu.be") { return .youtube }
        if lower.contains("tiktok")                                 { return .tiktok }
        if lower.contains("instagram")                              { return .instagram }
        if lower.contains("spotify")                                { return .spotify }
        if lower.contains(".com") || lower.contains("http")        { return .article }
        return .bare
    }
}

@Model
public final class Link {
    public var id: String
    public var urlString: String
    public var title: String
    public var host: String
    public var kind: LinkKind
    public var author: String?
    public var duration: String?
    public var readTime: String?
    public var thumbnailURL: String?
    /// Locally cached thumbnail bytes. Some hosts (e.g. Instagram/fbcdn) serve
    /// signed URLs that expire after a few days — we download and persist the
    /// image here so the preview survives. Stored outside the main store.
    @Attribute(.externalStorage) public var thumbnailData: Data?
    public var tags: [String]
    public var userNote: String?
    public var aspectRatio: Double
    public var createdAt: Date
    public var isArchived: Bool

    public init(
        id: String = UUID().uuidString,
        urlString: String,
        title: String,
        host: String,
        kind: LinkKind = .bare,
        author: String? = nil,
        duration: String? = nil,
        readTime: String? = nil,
        thumbnailURL: String? = nil,
        thumbnailData: Data? = nil,
        tags: [String] = [],
        userNote: String? = nil,
        aspectRatio: Double = 1.0,
        createdAt: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.host = host
        self.kind = kind
        self.author = author
        self.duration = duration
        self.readTime = readTime
        self.thumbnailURL = thumbnailURL
        self.thumbnailData = thumbnailData
        self.tags = tags
        self.userNote = userNote
        self.aspectRatio = aspectRatio
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}

// MARK: - Sample data (shown until real URLs are captured)

extension Link {
    static let samples: [Link] = [
        Link(id: "l1", urlString: "https://youtube.com", title: "How Wabi designed for emotional restraint",
             host: "youtube.com", kind: .youtube, author: "@cleartype", duration: "14:22", aspectRatio: 1.0),
        Link(id: "l2", urlString: "https://tiktok.com", title: "one-take kitchen lighting test",
             host: "tiktok.com", kind: .tiktok, author: "@frankochieng", aspectRatio: 1.6),
        Link(id: "l3", urlString: "https://newyorker.com", title: "In praise of the boring interface",
             host: "newyorker.com", kind: .article, readTime: "9 min", aspectRatio: 0.7),
        Link(id: "l4", urlString: "https://instagram.com", title: "kintsugi vase, ash glaze",
             host: "instagram.com", kind: .instagram, author: "@studiokoma", aspectRatio: 1.25),
        Link(id: "l5", urlString: "https://open.spotify.com", title: "all melody — late edition",
             host: "open.spotify.com", kind: .spotify, author: "nils frahm", aspectRatio: 0.9),
        Link(id: "l6", urlString: "https://arxiv.org", title: "Mixture-of-experts for sparse activation",
             host: "arxiv.org", kind: .article, readTime: "12 min", aspectRatio: 0.85),
        Link(id: "l7", urlString: "https://mghof.fi", title: "mghof — slow studio. helsinki.",
             host: "mghof.fi", kind: .bare, aspectRatio: 1.1),
        Link(id: "l8", urlString: "https://youtube.com", title: "less, but better — 1979 lecture",
             host: "youtube.com", kind: .youtube, author: "@dieterrams", duration: "38:04", aspectRatio: 0.9),
    ]
}
