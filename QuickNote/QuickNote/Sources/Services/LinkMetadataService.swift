// LinkMetadataService.swift — fetches title, thumbnail, and author for saved links

import Foundation

struct FetchedLinkMetadata {
    var title: String?
    var thumbnailURLString: String?
    var author: String?
}

actor LinkMetadataService {
    static let shared = LinkMetadataService()
    private init() {}

    func fetch(urlString: String, kind: LinkKind) async -> FetchedLinkMetadata {
        switch kind {
        case .youtube:   return await fetchYouTube(urlString: urlString)
        case .spotify:   return await fetchOEmbed("https://open.spotify.com/oembed", url: urlString)
        case .instagram, .tiktok, .article, .bare: return await fetchOpenGraph(urlString: urlString)
        }
    }

    // MARK: - YouTube (oEmbed — no API key required)

    private func fetchYouTube(urlString: String) async -> FetchedLinkMetadata {
        var meta = await fetchOEmbed("https://www.youtube.com/oembed", url: urlString)
        // mqdefault.jpg is guaranteed 320×180 (true 16:9, no letterbox bars)
        if let vid = youtubeVideoID(from: urlString) {
            meta.thumbnailURLString = "https://img.youtube.com/vi/\(vid)/mqdefault.jpg"
        }
        return meta
    }

    // MARK: - Generic oEmbed

    private func fetchOEmbed(_ endpoint: String, url: String) async -> FetchedLinkMetadata {
        guard let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let reqURL = URL(string: "\(endpoint)?url=\(encoded)&format=json") else { return FetchedLinkMetadata() }
        do {
            let (data, resp) = try await URLSession.shared.data(from: reqURL)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return FetchedLinkMetadata() }
            let json = try JSONDecoder().decode(OEmbedResponse.self, from: data)
            return FetchedLinkMetadata(
                title: json.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                thumbnailURLString: json.thumbnail_url,
                author: json.author_name
            )
        } catch { return FetchedLinkMetadata() }
    }

    // MARK: - Open Graph scraping

    private func fetchOpenGraph(urlString: String) async -> FetchedLinkMetadata {
        let full = urlString.hasPrefix("http") ? urlString : "https://\(urlString)"
        guard let url = URL(string: full) else { return FetchedLinkMetadata() }
        do {
            var req = URLRequest(url: url, timeoutInterval: 10)
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                         forHTTPHeaderField: "User-Agent")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return FetchedLinkMetadata() }
            // Only parse the first 64 KB — OG tags are always in <head>
            let slice = data.prefix(65536)
            guard let html = String(data: slice, encoding: .utf8) ?? String(data: slice, encoding: .isoLatin1) else { return FetchedLinkMetadata() }
            return parseOG(html, baseURL: full)
        } catch { return FetchedLinkMetadata() }
    }

    private func parseOG(_ html: String, baseURL: String) -> FetchedLinkMetadata {
        func tag(_ prop: String) -> String? {
            for pattern in [
                #"property=["']\#(prop)["'][^>]*content=["']([^"'<>]{1,500})["']"#,
                #"content=["']([^"'<>]{1,500})["'][^>]*property=["']\#(prop)["']"#,
                #"name=["']\#(prop)["'][^>]*content=["']([^"'<>]{1,500})["']"#
            ] {
                if let rx = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let m = rx.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let r = Range(m.range(at: 1), in: html) {
                    return String(html[r]).htmlEntityDecoded
                }
            }
            return nil
        }

        var thumb = tag("og:image")
        // Resolve protocol-relative URLs (//example.com/...)
        if let t = thumb, t.hasPrefix("//") {
            thumb = "https:\(t)"
        }

        return FetchedLinkMetadata(
            title: tag("og:title") ?? tag("twitter:title"),
            thumbnailURLString: thumb ?? tag("twitter:image"),
            author: tag("og:site_name")
        )
    }

    // MARK: - YouTube video ID

    private func youtubeVideoID(from url: String) -> String? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        func take(after marker: String) -> String? {
            guard let range = url.range(of: marker) else { return nil }
            let suffix = url[range.upperBound...]
            let id = String(suffix.unicodeScalars.prefix(while: { allowed.contains($0) }).map(Character.init))
            return id.isEmpty ? nil : id
        }
        if let id = take(after: "youtu.be/") { return id }
        if let comps = URLComponents(string: url),
           let v = comps.queryItems?.first(where: { $0.name == "v" })?.value { return v }
        if let id = take(after: "/shorts/") { return id }
        if let id = take(after: "/embed/")  { return id }
        return nil
    }
}

// MARK: - Private types

private struct OEmbedResponse: Decodable {
    let title: String?
    let thumbnail_url: String?
    let author_name: String?
}

private extension String {
    var htmlEntityDecoded: String {
        var s = self
        [("&amp;","&"),("&lt;","<"),("&gt;",">"),("&quot;","\""),("&#39;","'"),("&apos;","'")].forEach {
            s = s.replacingOccurrences(of: $0.0, with: $0.1)
        }
        return s
    }
}
