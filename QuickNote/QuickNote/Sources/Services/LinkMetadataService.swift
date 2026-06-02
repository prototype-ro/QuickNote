// LinkMetadataService.swift — fetches title, thumbnail, and author for saved links

import Foundation

struct FetchedLinkMetadata {
    var title: String?
    var thumbnailURLString: String?
    var author: String?
    var product: ProductInfo?
}

actor LinkMetadataService {
    static let shared = LinkMetadataService()
    private init() {}

    func fetch(urlString: String, kind: LinkKind) async -> FetchedLinkMetadata {
        switch kind {
        case .youtube:   return await fetchYouTube(urlString: urlString)
        case .spotify:   return await fetchOEmbed("https://open.spotify.com/oembed", url: urlString)
        case .instagram: return await fetchInstagram(urlString: urlString)
        case .tiktok, .article, .bare, .product: return await fetchOpenGraph(urlString: urlString)
        }
    }

    // MARK: - Thumbnail download (for local caching)

    /// Downloads raw image bytes for a thumbnail URL, so callers can persist it
    /// before the URL expires. Returns nil on any failure or non-image response.
    func imageData(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            var req = URLRequest(url: url, timeoutInterval: 12)
            req.setValue(Self.crawlerUA, forHTTPHeaderField: "User-Agent")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  !data.isEmpty, data.count <= 6_000_000 else { return nil }
            // Sanity: reject obvious non-image payloads (HTML error pages).
            if let ct = http.value(forHTTPHeaderField: "Content-Type"),
               !ct.lowercased().hasPrefix("image/") { return nil }
            return data
        } catch { return nil }
    }

    // MARK: - Instagram (public /embed/ page — no API key)
    //
    // Instagram serves a login wall to ordinary user-agents, so og:image scraping
    // fails. The public embed endpoint, however, returns the media without auth.
    // We parse the inline "display_url" first, then fall back to a crawler-UA
    // Open Graph scrape. Best-effort: returns empty metadata if Instagram changes
    // its markup, never throws.

    private func fetchInstagram(urlString: String) async -> FetchedLinkMetadata {
        guard let shortcode = instagramShortcode(from: urlString) else {
            return await fetchOpenGraph(urlString: urlString, userAgent: Self.crawlerUA)
        }

        let embed = "https://www.instagram.com/p/\(shortcode)/embed/captioned/"
        if let url = URL(string: embed) {
            do {
                var req = URLRequest(url: url, timeoutInterval: 10)
                req.setValue(Self.crawlerUA, forHTTPHeaderField: "User-Agent")
                let (data, resp) = try await URLSession.shared.data(for: req)
                if (resp as? HTTPURLResponse)?.statusCode == 200,
                   let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
                    var meta = parseOG(html, baseURL: embed)
                    if meta.thumbnailURLString == nil {
                        // Try known JSON keys, then a raw CDN-image scrape as catch-all.
                        meta.thumbnailURLString = jsonString(in: html, key: "display_url")
                            ?? jsonString(in: html, key: "thumbnail_src")
                            ?? jsonString(in: html, key: "image_url")
                            ?? instagramCDNImage(in: html)
                    }
                    if meta.title == nil {
                        meta.title = jsonString(in: html, key: "caption")
                    }
                    if meta.thumbnailURLString != nil { return meta }
                }
            } catch { /* fall through */ }
        }

        // Fallback: crawler-UA Open Graph on the original URL
        return await fetchOpenGraph(urlString: urlString, userAgent: Self.crawlerUA)
    }

    private func instagramShortcode(from url: String) -> String? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        for marker in ["/p/", "/reel/", "/reels/", "/tv/"] {
            guard let range = url.range(of: marker) else { continue }
            let suffix = url[range.upperBound...]
            let code = String(suffix.unicodeScalars.prefix(while: { allowed.contains($0) }).map(Character.init))
            if !code.isEmpty { return code }
        }
        return nil
    }

    // Pull an escaped JSON string value, e.g. "display_url":"https:\/\/...&..."
    private func jsonString(in html: String, key: String) -> String? {
        let pattern = #""\#(key)"\s*:\s*"((?:[^"\\]|\\.)*)""#
        guard let rx = try? NSRegularExpression(pattern: pattern),
              let m = rx.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(m.range(at: 1), in: html) else { return nil }
        let raw = String(html[r])
        guard !raw.isEmpty else { return nil }
        return raw
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "\\u0026", with: "&")
            .replacingOccurrences(of: "\\u0025", with: "%")
            .replacingOccurrences(of: "\\n", with: " ")
            .htmlEntityDecoded
    }

    // Catch-all: pull the post's media image off Instagram's content CDN.
    // The embed HTML carries several CDN images — the author's profile pic plus
    // the actual media/cover frame. We skip profile pics (the t51.2885-19
    // namespace) and prefer the largest available media frame.
    private func instagramCDNImage(in html: String) -> String? {
        let pattern = #"https:(?:\\/\\/|//)[^"'\\ ]*?(?:scontent|fbcdn)[^"'\\ ]*?\.(?:jpg|jpeg|webp|png)[^"'\\ ]*"#
        guard let rx = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..., in: html)

        let candidates: [String] = rx.matches(in: html, range: range).compactMap { m in
            guard let r = Range(m.range, in: html) else { return nil }
            return String(html[r])
                .replacingOccurrences(of: "\\/", with: "/")
                .replacingOccurrences(of: "\\u0026", with: "&")
                .replacingOccurrences(of: "\\u0025", with: "%")
                .htmlEntityDecoded // &amp; -> &, etc.
        }
        // Drop profile pictures — keep only post media frames.
        let media = candidates.filter { !$0.contains("t51.2885-19") && !$0.contains("profile_pic") }
        guard !media.isEmpty else { return nil }

        // Prefer the highest-resolution frame when size hints are present.
        for hint in ["1080", "750", "640", "480", "320", "240"] {
            if let best = media.first(where: { $0.contains(hint) }) { return best }
        }
        return media.first
    }

    private static let crawlerUA = "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)"

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

    private func fetchOpenGraph(urlString: String,
                                userAgent: String = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15") async -> FetchedLinkMetadata {
        let full = urlString.hasPrefix("http") ? urlString : "https://\(urlString)"
        guard let url = URL(string: full) else { return FetchedLinkMetadata() }
        do {
            var req = URLRequest(url: url, timeoutInterval: 10)
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return FetchedLinkMetadata() }
            // Parse the first 200 KB — JSON-LD Product blocks can sit lower than OG tags.
            let slice = data.prefix(200_000)
            guard let html = String(data: slice, encoding: .utf8) ?? String(data: slice, encoding: .isoLatin1) else { return FetchedLinkMetadata() }
            var meta = parseOG(html, baseURL: full)
            meta.product = Self.parseProduct(html)
            return meta
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

    // MARK: - Product detection (JSON-LD schema.org/Product + OG product tags)

    /// Extracts product info from page HTML. Tries JSON-LD `Product` first, then
    /// OpenGraph product meta tags. Returns nil if the page isn't a product.
    static func parseProduct(_ html: String) -> ProductInfo? {
        if let p = parseJSONLDProduct(html) { return p }
        return parseOGProduct(html)
    }

    private static func parseJSONLDProduct(_ html: String) -> ProductInfo? {
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let rx = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        for m in rx.matches(in: html, range: range) {
            guard let r = Range(m.range(at: 1), in: html) else { continue }
            let json = String(html[r])
            guard let data = json.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let node = findProductNode(in: obj) {
                return productInfo(from: node)
            }
        }
        return nil
    }

    /// Recursively finds a node whose @type is "Product" within decoded JSON-LD
    /// (which may be a dict, an array, or use @graph).
    private static func findProductNode(in any: Any) -> [String: Any]? {
        if let dict = any as? [String: Any] {
            let type = dict["@type"]
            if (type as? String) == "Product" || (type as? [String])?.contains("Product") == true {
                return dict
            }
            if let graph = dict["@graph"], let found = findProductNode(in: graph) { return found }
            for value in dict.values {
                if let found = findProductNode(in: value) { return found }
            }
        } else if let arr = any as? [Any] {
            for value in arr {
                if let found = findProductNode(in: value) { return found }
            }
        }
        return nil
    }

    private static func productInfo(from node: [String: Any]) -> ProductInfo? {
        let name = (node["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }

        let brand: String? = {
            if let s = node["brand"] as? String { return s }
            if let d = node["brand"] as? [String: Any] { return d["name"] as? String }
            return nil
        }()

        // offers may be a dict or an array of dicts
        let offer: [String: Any]? = {
            if let d = node["offers"] as? [String: Any] { return d }
            if let a = node["offers"] as? [Any] { return a.first as? [String: Any] }
            return nil
        }()
        let currency = offer?["priceCurrency"] as? String
        let priceText: String? = {
            guard let offer else { return nil }
            let raw: String?
            if let s = offer["price"] as? String { raw = s }
            else if let n = offer["price"] as? NSNumber { raw = n.stringValue }
            else { raw = nil }
            guard let raw, !raw.isEmpty else { return nil }
            return [currency, raw].compactMap { $0 }.joined(separator: " ")
        }()
        let availability: String? = {
            guard let a = offer?["availability"] as? String else { return nil }
            // schema URLs look like "https://schema.org/InStock"
            let tail = a.split(separator: "/").last.map(String.init) ?? a
            if tail.lowercased().contains("instock") { return "in stock" }
            if tail.lowercased().contains("outofstock") { return "out of stock" }
            return nil
        }()

        return ProductInfo(name: name, brand: brand, priceText: priceText,
                           currency: currency, availability: availability)
    }

    private static func parseOGProduct(_ html: String) -> ProductInfo? {
        func meta(_ prop: String) -> String? {
            for pattern in [
                #"property=["']\#(prop)["'][^>]*content=["']([^"'<>]{1,300})["']"#,
                #"content=["']([^"'<>]{1,300})["'][^>]*property=["']\#(prop)["']"#,
                #"name=["']\#(prop)["'][^>]*content=["']([^"'<>]{1,300})["']"#
            ] {
                if let rx = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let m = rx.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let r = Range(m.range(at: 1), in: html) {
                    return String(html[r]).htmlEntityDecoded
                }
            }
            return nil
        }
        let type = meta("og:type")
        let amount = meta("product:price:amount") ?? meta("og:price:amount")
        // Only treat as product if it declares product type or exposes a price.
        guard type?.lowercased().contains("product") == true || amount != nil else { return nil }
        guard let name = meta("og:title"), !name.isEmpty else { return nil }
        let currency = meta("product:price:currency") ?? meta("og:price:currency")
        let priceText = amount.map { [currency, $0].compactMap { $0 }.joined(separator: " ") }
        return ProductInfo(name: name, brand: meta("og:brand") ?? meta("product:brand"),
                           priceText: priceText, currency: currency, availability: nil)
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
