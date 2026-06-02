# Smart Cards — Movie & Product Enrichment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich captured movies (TMDB) in the Mind feed and product links (JSON-LD) in the Library, marking each with a quiet ✦ and revealing all AI-gathered detail inside the card on open; plus retune Library platform pills to be quieter.

**Architecture:** Detection reuses the single existing capture-classify Claude call (adds an optional `media` field). Enrichment is stored as a Codable struct attribute on the host model (`Note.media: MediaInfo?`, `Link.product: ProductInfo?`), with images cached as `Data` (mirrors existing `Link.thumbnailData`). All enrichment is async, best-effort, and never blocks capture. Cards stay calm; richness renders only in the detail views.

**Tech Stack:** SwiftUI, SwiftData (`@Model`), async/await URLSession, Anthropic API (existing), TMDB REST API (new, free key).

---

## Testing note (read first)

This project has **no test target** (verified: zero unit-test bundles in `project.pbxproj`). Adding one requires `.pbxproj` surgery, which the project's CLAUDE.md fences off. Therefore each task is verified by a **build gate** (the workflow proven throughout this codebase) plus a targeted manual check. Keep parsing/decoding logic in pure `static` functions so it stays trivially testable if a test target is added later.

**Build-verify command (used as the test gate in every task):**
```bash
cd /Users/rodgz_mac/Developer/QuickNote && \
xcodebuild build -project QuickNote/QuickNote.xcodeproj -scheme QuickNote \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:"
```
Expected after each task: `** BUILD SUCCEEDED **`, no `error:` lines.

**Paths:** repo root is `/Users/rodgz_mac/Developer/QuickNote`. Sources live under `QuickNote/QuickNote/Sources/`. Run all `git` commands from the repo root. SourceKit "Cannot find type" diagnostics across files are noise in this project — trust the build.

---

## File Structure

**Create:**
- `QuickNote/QuickNote/Sources/Core/Models/MediaInfo.swift` — `MediaInfo` Codable struct (movie enrichment payload).
- `QuickNote/QuickNote/Sources/Core/Models/ProductInfo.swift` — `ProductInfo` Codable struct (product enrichment payload).
- `QuickNote/QuickNote/Sources/Services/TMDBService.swift` — TMDB search + details + poster download.

**Modify:**
- `QuickNote/QuickNote/Sources/Core/Models/Note.swift` — add `media: MediaInfo?`.
- `QuickNote/QuickNote/Sources/Core/Models/Link.swift` — add `product: ProductInfo?` + `LinkKind.product`.
- `QuickNote/QuickNote/Sources/Core/Secrets.swift` — add `tmdbAPIKey`.
- `QuickNote/QuickNote/Sources/Services/NoteProcessor.swift` — classify `media` field + TMDB fill in `createNote`.
- `QuickNote/QuickNote/Sources/Services/LinkMetadataService.swift` — JSON-LD/OG product parse on `FetchedLinkMetadata`.
- `QuickNote/QuickNote/Sources/Features/Library/LinkComponents.swift` — quiet `PlatformPill`, `PRODUCT ✦` marker, `.product` aspect ratio.
- `QuickNote/QuickNote/Sources/Features/Library/LibraryView.swift` — apply product to `Link` in metadata flow.
- `QuickNote/QuickNote/Sources/Features/Mind/MindView.swift` — apply product to `Link` in paste flow.
- `QuickNote/QuickNote/Sources/Features/Mind/NoteComponents.swift` — ✦ marker on `NoteCard` when `media != nil`.
- `QuickNote/QuickNote/Sources/Features/Mind/NoteDetailSheet.swift` — movie hero section.
- `QuickNote/QuickNote/Sources/Features/Library/LinkDetailPeek.swift` — product section.

---

## Task 1: MediaInfo model + Note.media

**Files:**
- Create: `QuickNote/QuickNote/Sources/Core/Models/MediaInfo.swift`
- Modify: `QuickNote/QuickNote/Sources/Core/Models/Note.swift`

- [ ] **Step 1: Create MediaInfo**

Create `QuickNote/QuickNote/Sources/Core/Models/MediaInfo.swift`:
```swift
// MediaInfo.swift — AI-gathered enrichment for a media note (currently movies).
// Stored as a single Codable attribute on Note. All fields optional except the
// identifier/title so partial TMDB data still renders.

import Foundation

public struct MediaInfo: Codable, Equatable {
    public var tmdbID: Int
    public var title: String
    public var year: String?
    public var rating: Double?      // TMDB vote average, e.g. 7.4
    public var runtime: Int?        // minutes
    public var genre: String?       // primary genre name
    public var overview: String?    // synopsis
    public var posterData: Data?    // cached poster image bytes

    public init(tmdbID: Int, title: String, year: String? = nil, rating: Double? = nil,
                runtime: Int? = nil, genre: String? = nil, overview: String? = nil,
                posterData: Data? = nil) {
        self.tmdbID = tmdbID
        self.title = title
        self.year = year
        self.rating = rating
        self.runtime = runtime
        self.genre = genre
        self.overview = overview
        self.posterData = posterData
    }

    /// Compact one-line meta: "2026 · ★ 7.4 · 1h 52m · Drama" (omits missing parts).
    public var metaLine: String {
        var parts: [String] = []
        if let year { parts.append(year) }
        if let rating { parts.append(String(format: "★ %.1f", rating)) }
        if let runtime { parts.append("\(runtime / 60)h \(runtime % 60)m") }
        if let genre { parts.append(genre) }
        return parts.joined(separator: " · ")
    }
}
```

- [ ] **Step 2: Add media to Note**

In `QuickNote/QuickNote/Sources/Core/Models/Note.swift`, after the `dueDate`/event fields block (the lines added previously, ending with `public var calendarEventID: String? = nil`), add:
```swift
    /// AI media enrichment (movie info + cached poster). nil → ordinary note.
    /// Optional → migration-safe. Drives the ✦ marker and the movie hero in detail.
    public var media: MediaInfo? = nil
```

- [ ] **Step 3: Add hasMedia helper**

In `Note.swift`, after the `hasPendingEvent` computed property, add:
```swift
    /// Whether this note carries media enrichment (renders ✦ + movie hero).
    public var hasMedia: Bool { media != nil }
```

- [ ] **Step 4: Build-verify**

Run the build-verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**
```bash
cd /Users/rodgz_mac/Developer/QuickNote
git add QuickNote/QuickNote/Sources/Core/Models/MediaInfo.swift QuickNote/QuickNote/Sources/Core/Models/Note.swift
git commit -m "feat: add MediaInfo enrichment to Note model"
```

---

## Task 2: ProductInfo model + Link.product + LinkKind.product

**Files:**
- Create: `QuickNote/QuickNote/Sources/Core/Models/ProductInfo.swift`
- Modify: `QuickNote/QuickNote/Sources/Core/Models/Link.swift`

- [ ] **Step 1: Create ProductInfo**

Create `QuickNote/QuickNote/Sources/Core/Models/ProductInfo.swift`:
```swift
// ProductInfo.swift — AI-gathered enrichment for a product link.
// Stored as a single Codable attribute on Link. price is a one-time snapshot
// (no tracking). Image cached as bytes so it survives remote URL expiry.

import Foundation

public struct ProductInfo: Codable, Equatable {
    public var name: String
    public var brand: String?
    public var priceText: String?     // formatted, e.g. "€42.00"
    public var currency: String?      // ISO code when available, e.g. "EUR"
    public var availability: String?  // e.g. "in stock"
    public var imageData: Data?       // cached product image bytes

    public init(name: String, brand: String? = nil, priceText: String? = nil,
                currency: String? = nil, availability: String? = nil, imageData: Data? = nil) {
        self.name = name
        self.brand = brand
        self.priceText = priceText
        self.currency = currency
        self.availability = availability
        self.imageData = imageData
    }
}
```

- [ ] **Step 2: Add .product to LinkKind**

In `QuickNote/QuickNote/Sources/Core/Models/Link.swift`, change the enum cases line:
```swift
public enum LinkKind: String, Codable {
    case youtube, tiktok, instagram, spotify, article, bare
```
to:
```swift
public enum LinkKind: String, Codable {
    case youtube, tiktok, instagram, spotify, article, bare, product
```

- [ ] **Step 3: Add product platformLabel**

In `Link.swift`, in `LinkKind.platformLabel`, change:
```swift
        case .article, .bare: return nil
        }
```
to:
```swift
        case .product:   return "Product"
        case .article, .bare: return nil
        }
```

- [ ] **Step 4: Add product attribute to Link**

In `Link.swift`, after the `@Attribute(.externalStorage) public var thumbnailData: Data?` line, add:
```swift
    /// AI product enrichment (price/brand/image). nil → ordinary link.
    /// Optional → migration-safe. Drives the PRODUCT ✦ marker + product section.
    public var product: ProductInfo? = nil
```

- [ ] **Step 5: Add product to Link.init**

In `Link.swift` `init`, after the `thumbnailData: Data? = nil,` parameter add `product: ProductInfo? = nil,`, and after the `self.thumbnailData = thumbnailData` assignment add `self.product = product`.

- [ ] **Step 6: Build-verify**

Run the build-verify command. The new `.product` case will surface non-exhaustive `switch` warnings/errors in `LinkComponents.swift` (PlatformPill `config`, `containerRatio`) and any other switch over `LinkKind`. That is expected and fixed in Task 3. If the build fails ONLY on those switches, proceed to Task 3; otherwise fix the unexpected error first.

- [ ] **Step 7: Commit**
```bash
cd /Users/rodgz_mac/Developer/QuickNote
git add QuickNote/QuickNote/Sources/Core/Models/ProductInfo.swift QuickNote/QuickNote/Sources/Core/Models/Link.swift
git commit -m "feat: add ProductInfo enrichment and .product kind to Link model"
```

---

## Task 3: Quiet pills + PRODUCT marker + .product aspect ratio

**Files:**
- Modify: `QuickNote/QuickNote/Sources/Features/Library/LinkComponents.swift`

- [ ] **Step 1: Retune PlatformPill to quiet, neutral styling**

Replace the entire `PlatformPill` struct (currently at `LinkComponents.swift:82`) with:
```swift
struct PlatformPill: View {
    let kind: LinkKind

    private var label: String? {
        switch kind {
        case .youtube:   return "YouTube"
        case .tiktok:    return "TikTok"
        case .instagram: return "Instagram"
        case .spotify:   return "Spotify"
        case .product:   return "Product"
        case .article, .bare: return nil
        }
    }

    /// Products get a quiet ✦ to signal "enriched, more inside".
    private var showsSpark: Bool { kind == .product }

    var body: some View {
        if let label {
            HStack(spacing: 4) {
                Text(label)
                    .appFont(10, .medium, relativeTo: .caption2)
                    .tracking(0.3)
                    .textCase(.uppercase)
                if showsSpark {
                    Text("✦").appFont(9, .medium, relativeTo: .caption2)
                }
            }
            .foregroundStyle(.white.opacity(0.85))
            .fixedSize()
            .padding(.horizontal, 9)
            .frame(height: 20)
            .background(.ultraThinMaterial)
            .background(AppColors.ink.opacity(0.45))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        }
    }
}
```
This drops the bright per-brand colors (red/pink/green) for a single muted dark-glass pill across all platforms.

- [ ] **Step 2: Add .product to containerRatio**

In `LinkComponents.swift`, in `LinkThumbnail`'s `containerRatio` switch (currently ends with `case .article, .bare: return 3.0/2.0`), add a product case before it:
```swift
        case .product:    return 1.0
        case .article, .bare: return 3.0/2.0
```

- [ ] **Step 3: Show cached product image in thumbnail**

In `LinkComponents.swift`, in `LinkThumbnail.thumbnailContent`, change the first branch from:
```swift
        if let data = link.thumbnailData, let uiImage = UIImage(data: data) {
            // Locally cached bytes — survives remote URL expiry.
            Image(uiImage: uiImage).resizable().scaledToFill()
        } else if let urlString = link.thumbnailURL, let url = URL(string: urlString) {
```
to:
```swift
        if let data = link.product?.imageData, let uiImage = UIImage(data: data) {
            // Cached product image takes precedence for product links.
            Image(uiImage: uiImage).resizable().scaledToFill()
        } else if let data = link.thumbnailData, let uiImage = UIImage(data: data) {
            // Locally cached bytes — survives remote URL expiry.
            Image(uiImage: uiImage).resizable().scaledToFill()
        } else if let urlString = link.thumbnailURL, let url = URL(string: urlString) {
```

- [ ] **Step 4: Build-verify**

Run the build-verify command. Expected: `** BUILD SUCCEEDED **`, all `LinkKind` switch errors resolved.

- [ ] **Step 5: Commit**
```bash
cd /Users/rodgz_mac/Developer/QuickNote
git add QuickNote/QuickNote/Sources/Features/Library/LinkComponents.swift
git commit -m "feat: quiet platform pills, PRODUCT marker, product aspect ratio"
```

---

## Task 4: TMDB key + TMDBService

**Files:**
- Modify: `QuickNote/QuickNote/Sources/Core/Secrets.swift`
- Create: `QuickNote/QuickNote/Sources/Services/TMDBService.swift`

- [ ] **Step 1: Add TMDB key slot to Secrets**

In `QuickNote/QuickNote/Sources/Core/Secrets.swift`, add inside the `Secrets` enum (below the Anthropic key):
```swift
    // Paste your TMDB API Read Access Token (v4 bearer) below. Free at
    // https://www.themoviedb.org/settings/api . Leave "" to disable movie enrichment.
    static let tmdbAPIKey = ""
```

- [ ] **Step 2: Create TMDBService**

Create `QuickNote/QuickNote/Sources/Services/TMDBService.swift`:
```swift
// TMDBService.swift — looks up movie metadata + poster from TMDB (free API).
// Best-effort: returns nil on missing key, miss, or network failure. Never throws
// into the capture path. Uses the v4 bearer token from Secrets.tmdbAPIKey.

import Foundation

public actor TMDBService {
    public static let shared = TMDBService()
    private let bearer: String
    private init() { self.bearer = Secrets.tmdbAPIKey }

    private static let imageBase = "https://image.tmdb.org/t/p/w500"

    /// Searches for a movie by free-text query and returns enriched info with a
    /// cached poster, or nil if unavailable.
    public func lookup(query: String) async -> MediaInfo? {
        guard !bearer.isEmpty else { return nil }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let first = await search(trimmed) else { return nil }
        let detailed = await details(id: first.id) ?? first

        var info = MediaInfo(
            tmdbID: detailed.id,
            title: detailed.title,
            year: detailed.release_date.flatMap { String($0.prefix(4)) }.flatMap { $0.isEmpty ? nil : $0 },
            rating: detailed.vote_average,
            runtime: detailed.runtime,
            genre: detailed.genres?.first?.name,
            overview: detailed.overview?.isEmpty == false ? detailed.overview : nil
        )
        if let path = detailed.poster_path {
            info.posterData = await downloadPoster(path: path)
        }
        return info
    }

    // MARK: - Requests

    private func search(_ query: String) async -> TMDBMovie? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.themoviedb.org/3/search/movie?query=\(encoded)&include_adult=false&language=en-US&page=1") else { return nil }
        guard let data = await get(url) else { return nil }
        let results = try? JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        return results?.results.first
    }

    private func details(id: Int) async -> TMDBMovie? {
        guard let url = URL(string: "https://api.themoviedb.org/3/movie/\(id)?language=en-US") else { return nil }
        guard let data = await get(url) else { return nil }
        return try? JSONDecoder().decode(TMDBMovie.self, from: data)
    }

    private func downloadPoster(path: String) async -> Data? {
        guard let url = URL(string: Self.imageBase + path) else { return nil }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  !data.isEmpty, data.count <= 6_000_000 else { return nil }
            return data
        } catch { return nil }
    }

    private func get(_ url: URL) async -> Data? {
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "accept")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return data
        } catch { return nil }
    }
}

// MARK: - TMDB response types

private struct TMDBSearchResponse: Decodable { let results: [TMDBMovie] }

private struct TMDBMovie: Decodable {
    let id: Int
    let title: String
    let overview: String?
    let release_date: String?
    let vote_average: Double?
    let poster_path: String?
    let runtime: Int?
    let genres: [TMDBGenre]?
}

private struct TMDBGenre: Decodable { let id: Int; let name: String }
```

- [ ] **Step 3: Build-verify**

Run the build-verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**
```bash
cd /Users/rodgz_mac/Developer/QuickNote
git add QuickNote/QuickNote/Sources/Core/Secrets.swift QuickNote/QuickNote/Sources/Services/TMDBService.swift
git commit -m "feat: add TMDBService for movie metadata + poster"
```

---

## Task 5: Classify media field + TMDB fill in createNote

**Files:**
- Modify: `QuickNote/QuickNote/Sources/Services/NoteProcessor.swift`

- [ ] **Step 1: Add DetectedMedia type + media field on ProcessedNoteResponse**

In `NoteProcessor.swift`, just below the `DetectedEvent` struct, add:
```swift
/// A media item the model found in free text (currently movies). `query` is a
/// search string for TMDB, e.g. "Obsession".
public struct DetectedMedia: Codable {
    public let kind: String     // "movie"
    public let query: String
}
```
Then in `ProcessedNoteResponse`, add a stored property and init parameter:
- After `public var event: DetectedEvent?` add:
```swift
    /// Media (movie) detected for enrichment, when clearly present.
    public var media: DetectedMedia?
```
- Change the `init` signature from:
```swift
    public init(type: String, tasks: [String], tags: [String], summary: String,
                event: DetectedEvent? = nil) {
```
to:
```swift
    public init(type: String, tasks: [String], tags: [String], summary: String,
                event: DetectedEvent? = nil, media: DetectedMedia? = nil) {
```
- At the end of the `init` body (after `self.event = event`) add:
```swift
        self.media = media
```

- [ ] **Step 2: Extend the classify system prompt with a media field**

In `apiProcess`, inside the `systemPrompt` string, after the `- event:` bullet block (the line ending `...must ALSO appear in the tasks array.`) and before the final `Respond ONLY with valid JSON...` line, add:
```
        - media: an object IF the note expresses intent to watch/see a specific named MOVIE (e.g. "watch obsession saturday", "see the new dune movie"). Otherwise null. When present: { "kind": "movie", "query": "<the movie's title only, no extra words>" }. Only set this for movies, not music, articles, or generic links.
```

- [ ] **Step 3: Pass media through parseClassifyResponse**

In `parseClassifyResponse`, change the reconstructed return from:
```swift
            return ProcessedNoteResponse(
                type: raw.type,
                tasks: raw.tasks.map { Self.stripMarkdown($0) },
                tags: raw.tags,
                summary: Self.stripMarkdown(raw.summary),
                event: raw.event
            )
```
to:
```swift
            return ProcessedNoteResponse(
                type: raw.type,
                tasks: raw.tasks.map { Self.stripMarkdown($0) },
                tags: raw.tags,
                summary: Self.stripMarkdown(raw.summary),
                event: raw.event,
                media: raw.media
            )
```

- [ ] **Step 4: Fill note.media in createNote**

In `createNote`, change the tail from:
```swift
        if let event = processed.event, let date = Self.parseEventDate(event.date) {
            note.eventTitle = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            note.eventDate = date
            note.eventHasTime = event.hasTime
            if note.dueDate == nil { note.dueDate = date }
        }
        return note
    }
```
to:
```swift
        if let event = processed.event, let date = Self.parseEventDate(event.date) {
            note.eventTitle = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            note.eventDate = date
            note.eventHasTime = event.hasTime
            if note.dueDate == nil { note.dueDate = date }
        }
        if let media = processed.media, media.kind == "movie" {
            note.media = await TMDBService.shared.lookup(query: media.query)
        }
        return note
    }
```

- [ ] **Step 5: Build-verify**

Run the build-verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**
```bash
cd /Users/rodgz_mac/Developer/QuickNote
git add QuickNote/QuickNote/Sources/Services/NoteProcessor.swift
git commit -m "feat: detect movies in classify call and fill Note.media via TMDB"
```

---

## Task 6: ✦ marker on NoteCard

**Files:**
- Modify: `QuickNote/QuickNote/Sources/Features/Mind/NoteComponents.swift`

- [ ] **Step 1: Add a quiet ✦ beside the timestamp when media is present**

In `NoteComponents.swift`, in `NoteCard.cardFace`, locate the header `HStack` that holds `NoteBadge` and the `relativeTime` text (around `NoteBadge(kind: note.type, animate: isNew)` ... `Text(relativeTime)`). Inside the trailing `HStack(spacing: 6)` that contains `Text(relativeTime)`, add a ✦ before the time text. Change:
```swift
                HStack(spacing: 6) {
                    Text(relativeTime)
                        .appFont(12, .light, relativeTo: .caption)
                        .tracking(-0.1)
                        .foregroundStyle(AppColors.secondaryText)
```
to:
```swift
                HStack(spacing: 6) {
                    if note.hasMedia {
                        Text("✦")
                            .appFont(11, .medium, relativeTo: .caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .accessibilityLabel("enriched")
                    }
                    Text(relativeTime)
                        .appFont(12, .light, relativeTo: .caption)
                        .tracking(-0.1)
                        .foregroundStyle(AppColors.secondaryText)
```

- [ ] **Step 2: Build-verify**

Run the build-verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**
```bash
cd /Users/rodgz_mac/Developer/QuickNote
git add QuickNote/QuickNote/Sources/Features/Mind/NoteComponents.swift
git commit -m "feat: quiet enriched marker on note cards with media"
```

---

## Task 7: Movie hero section in NoteDetailSheet

**Files:**
- Modify: `QuickNote/QuickNote/Sources/Features/Mind/NoteDetailSheet.swift`

- [ ] **Step 1: Insert the movie hero above the event card**

In `NoteDetailSheet.swift`, in `sheetContent`, find:
```swift
                    noteTextArea.padding(.bottom, 18)

                    if note.hasPendingEvent {
                        eventCard.padding(.bottom, 18)
                    }
```
and change it to:
```swift
                    noteTextArea.padding(.bottom, 18)

                    if note.hasMedia {
                        movieHero.padding(.bottom, 18)
                    }

                    if note.hasPendingEvent {
                        eventCard.padding(.bottom, 18)
                    }
```

- [ ] **Step 2: Add the movieHero view**

In `NoteDetailSheet.swift`, immediately above the `private var eventCard:` declaration, add:
```swift
    // MARK: - Movie hero (media enrichment)

    @ViewBuilder
    private var movieHero: some View {
        if let media = note.media {
            VStack(alignment: .leading, spacing: 0) {
                if let data = media.posterData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.bottom, 12)
                }
                Text(media.title)
                    .appFont(18, .semibold, relativeTo: .title3)
                    .tracking(-0.3)
                    .foregroundStyle(AppColors.primaryText)
                if !media.metaLine.isEmpty {
                    Text(media.metaLine)
                        .appFont(12.5, .light, relativeTo: .caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .padding(.top, 3)
                }
                if let overview = media.overview {
                    Text(overview)
                        .appFont(13, .light, relativeTo: .subheadline)
                        .lineSpacing(4)
                        .foregroundStyle(AppColors.secondaryText)
                        .padding(.top, 8)
                }
            }
        }
    }
```

- [ ] **Step 3: Build-verify**

Run the build-verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**
```bash
cd /Users/rodgz_mac/Developer/QuickNote
git add QuickNote/QuickNote/Sources/Features/Mind/NoteDetailSheet.swift
git commit -m "feat: movie hero section in note detail"
```

---

## Task 8: Product parse in LinkMetadataService

**Files:**
- Modify: `QuickNote/QuickNote/Sources/Services/LinkMetadataService.swift`

- [ ] **Step 1: Add product to FetchedLinkMetadata**

In `LinkMetadataService.swift`, change the struct:
```swift
struct FetchedLinkMetadata {
    var title: String?
    var thumbnailURLString: String?
    var author: String?
}
```
to:
```swift
struct FetchedLinkMetadata {
    var title: String?
    var thumbnailURLString: String?
    var author: String?
    var product: ProductInfo?
}
```

- [ ] **Step 2: Parse product in the Open Graph path**

In `fetchOpenGraph`, change the success branch from:
```swift
            // Only parse the first 64 KB — OG tags are always in <head>
            let slice = data.prefix(65536)
            guard let html = String(data: slice, encoding: .utf8) ?? String(data: slice, encoding: .isoLatin1) else { return FetchedLinkMetadata() }
            return parseOG(html, baseURL: full)
```
to:
```swift
            // Parse the first 200 KB — JSON-LD Product blocks can sit lower than OG tags.
            let slice = data.prefix(200_000)
            guard let html = String(data: slice, encoding: .utf8) ?? String(data: slice, encoding: .isoLatin1) else { return FetchedLinkMetadata() }
            var meta = parseOG(html, baseURL: full)
            meta.product = Self.parseProduct(html)
            return meta
```

- [ ] **Step 3: Add the product parser**

In `LinkMetadataService.swift`, just below the `parseOG` method, add:
```swift
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

        let image: String? = {
            if let s = node["image"] as? String { return s }
            if let a = node["image"] as? [Any] { return a.first as? String }
            if let d = node["image"] as? [String: Any] { return d["url"] as? String }
            return nil
        }()

        var info = ProductInfo(name: name, brand: brand, priceText: priceText,
                               currency: currency, availability: availability)
        // imageData is downloaded by the caller (LibraryView) using `image` via thumbnailURL.
        _ = image
        return info
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
```

- [ ] **Step 4: Route product detection for the article/bare kinds**

In `fetch(urlString:kind:)`, the `.tiktok, .article, .bare` branch already calls `fetchOpenGraph`, which now also fills `product`. No routing change needed for those. Confirm the switch still reads:
```swift
        case .tiktok, .article, .bare: return await fetchOpenGraph(urlString: urlString)
```
No edit required if it matches; otherwise restore it to this.

- [ ] **Step 5: Build-verify**

Run the build-verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**
```bash
cd /Users/rodgz_mac/Developer/QuickNote
git add QuickNote/QuickNote/Sources/Services/LinkMetadataService.swift
git commit -m "feat: detect products via JSON-LD and OG tags in link metadata"
```

---

## Task 9: Apply product to Link in the save flows

**Files:**
- Modify: `QuickNote/QuickNote/Sources/Features/Library/LibraryView.swift`
- Modify: `QuickNote/QuickNote/Sources/Features/Mind/MindView.swift`

- [ ] **Step 1: Apply product + promote kind in LibraryView**

In `LibraryView.swift`, in `fetchAndApplyMetadata`, change the `MainActor.run` block from:
```swift
            await MainActor.run {
                if let title = meta.title, !title.isEmpty { link.title = title }
                if let thumb = meta.thumbnailURLString { link.thumbnailURL = thumb }
                if let imageData { link.thumbnailData = imageData }
                if let author = meta.author { link.author = author }
            }
```
to:
```swift
            await MainActor.run {
                if let title = meta.title, !title.isEmpty { link.title = title }
                if let thumb = meta.thumbnailURLString { link.thumbnailURL = thumb }
                if let imageData { link.thumbnailData = imageData }
                if let author = meta.author { link.author = author }
                if var product = meta.product {
                    product.imageData = imageData ?? link.thumbnailData
                    link.product = product
                    link.kind = .product
                }
            }
```

- [ ] **Step 2: Apply product in MindView paste flow**

In `MindView.swift`, in the paste-to-library `Task { @MainActor in ... }` block, change:
```swift
                if let title = meta.title, !title.isEmpty { link.title = title }
                if let thumb = meta.thumbnailURLString { link.thumbnailURL = thumb }
                if let author = meta.author { link.author = author }
                if let thumb = meta.thumbnailURLString,
                   let data = await LinkMetadataService.shared.imageData(from: thumb) {
                    link.thumbnailData = data
                }
```
to:
```swift
                if let title = meta.title, !title.isEmpty { link.title = title }
                if let thumb = meta.thumbnailURLString { link.thumbnailURL = thumb }
                if let author = meta.author { link.author = author }
                var downloadedThumb: Data? = nil
                if let thumb = meta.thumbnailURLString {
                    downloadedThumb = await LinkMetadataService.shared.imageData(from: thumb)
                    if let downloadedThumb { link.thumbnailData = downloadedThumb }
                }
                if var product = meta.product {
                    product.imageData = downloadedThumb ?? link.thumbnailData
                    link.product = product
                    link.kind = .product
                }
```

- [ ] **Step 3: Build-verify**

Run the build-verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**
```bash
cd /Users/rodgz_mac/Developer/QuickNote
git add QuickNote/QuickNote/Sources/Features/Library/LibraryView.swift QuickNote/QuickNote/Sources/Features/Mind/MindView.swift
git commit -m "feat: promote saved links to products when product info is found"
```

---

## Task 10: Product section in LinkDetailPeek

**Files:**
- Modify: `QuickNote/QuickNote/Sources/Features/Library/LinkDetailPeek.swift`

- [ ] **Step 1: Insert the product section above the URL section**

In `LinkDetailPeek.swift`, in `body`, find the section list (around `titleSection` / `urlSection`):
```swift
                            titleSection

                            urlSection
```
and change it to:
```swift
                            titleSection

                            if link.product != nil {
                                productSection
                            }

                            urlSection
```
(Match the existing spacing/`Divider` pattern used between sections in this file; if sections are separated by explicit spacers or dividers, mirror that around `productSection`.)

- [ ] **Step 2: Add the productSection view**

In `LinkDetailPeek.swift`, immediately above `private var urlSection:`, add:
```swift
    // MARK: - Product (enrichment)

    @ViewBuilder
    private var productSection: some View {
        if let product = link.product {
            VStack(alignment: .leading, spacing: 8) {
                Text("PRODUCT")
                    .appFont(10.5, .medium, relativeTo: .caption2)
                    .tracking(1.4)
                    .foregroundStyle(AppColors.tertiaryText)

                if let data = product.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text(product.name)
                    .appFont(15, .semibold, relativeTo: .body)
                    .tracking(-0.2)
                    .foregroundStyle(AppColors.primaryText)

                HStack(spacing: 8) {
                    if let price = product.priceText {
                        Text(price)
                            .appFont(14, .semibold, relativeTo: .subheadline)
                            .foregroundStyle(AppColors.primaryText)
                    }
                    if let brand = product.brand {
                        Text(brand)
                            .appFont(12, .light, relativeTo: .caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    if let availability = product.availability {
                        Text("· \(availability)")
                            .appFont(12, .light, relativeTo: .caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
            }
        }
    }
```

- [ ] **Step 3: Build-verify**

Run the build-verify command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**
```bash
cd /Users/rodgz_mac/Developer/QuickNote
git add QuickNote/QuickNote/Sources/Features/Library/LinkDetailPeek.swift
git commit -m "feat: product section in link detail peek"
```

---

## Task 11: Manual end-to-end verification (device)

**No code.** Confirm the full flows on a device (simulator has no TMDB key gating issues but no real calendar UI).

- [ ] **Step 1: Configure keys**

Ensure `Secrets.tmdbAPIKey` holds a valid TMDB v4 bearer token. Without it, movie enrichment is silently disabled (by design).

- [ ] **Step 2: Movie flow**

Capture: `watch obsession movie saturday`. Expected: the note appears in Mind with a quiet ✦ next to its timestamp. Open it → movie hero shows poster + `year · ★rating · runtime · genre` + overview, and the `📅 add` event card appears below for Saturday. Tap add → event lands in Apple Calendar.

- [ ] **Step 3: Product flow**

In Library → add link → paste a product URL with structured data (e.g. a Shopify/known retail product page). Expected: the card shows the quiet `Product ✦` pill (not a bright brand color). Open it → product section shows image, price, brand, availability.

- [ ] **Step 4: Negatives (graceful fallback)**

Capture a normal thought (no movie) → no ✦, plain note. Save a plain article link → stays an article card, no product section. Confirm captures/links are never lost when TMDB/scrape returns nothing.

- [ ] **Step 5: Pills are quiet**

Open Library with existing YouTube/Instagram/Spotify links → pills render as muted dark-glass (no red/pink/green). 

---

## Self-Review Notes

- **Spec coverage:** MediaInfo (T1), ProductInfo+kind (T2), quiet pills (T3), TMDBService+key (T4), classify media+fill (T5), ✦ marker (T6), movie hero (T7), product parse JSON-LD+OG+ (T8), save-flow wiring (T9), product section (T10), manual E2E (T11). All spec sections mapped.
- **Curated fallbacks:** the spec mentions "a couple curated retailer fallbacks." Generic JSON-LD + OG covers most retailers (incl. Shopify, many Nike/Zara pages). Per-retailer fallbacks are deferred to a follow-up if a target site exposes neither — added as a note here rather than speculative code (YAGNI). If a specific site is required, add a dedicated parser branch in `parseProduct` keyed on host.
- **Type consistency:** `MediaInfo`, `ProductInfo`, `DetectedMedia`, `FetchedLinkMetadata.product`, `ProcessedNoteResponse.media`, `Note.media`/`hasMedia`, `Link.product`/`.product` kind used consistently across tasks.
- **No live showtimes / no chat / no price tracking** — honored; price is snapshot text only.
