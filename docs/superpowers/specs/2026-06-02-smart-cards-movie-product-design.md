# Smart Cards — Movie & Product Enrichment

**Date:** 2026-06-02
**Status:** Approved design, ready for implementation planning

## Summary

Two AI-enrichment features that keep QuickNote's calm "capture = thought" core
intact:

1. **Movie capture** — typing a thought like "watch obsession saturday" detects a
   movie, fetches its info + poster from TMDB, and renders the note as an enriched
   card. The feed stays calm; the card is marked only with a quiet ✦, and all
   AI-gathered detail lives *inside* on open. A single gentle inline calendar
   prompt lets the user schedule it.
2. **Product links** — saving a product URL (e.g. a Nike shirt) to the Library
   detects it as a product, scrapes name/brand/price/image, and marks the card
   with a quiet `PRODUCT ✦`. Price/specs live inside on open, not on the shelf.

Both follow one pattern: **detect → fetch external data → cache a Codable blob →
mark the card with ✦ → reveal detail inside.** Enrichment is always async,
best-effort, and never blocks capture.

## Guiding principle

The app's identity is calm capture and meaningful "reveal on open" moments — not
a cluttered utility or chatbot. Therefore:

- The feed/shelf stays visually quiet. Enriched items get a **subtle ✦ marker
  only** — no data spilled outward.
- All gathered information is **revealed inside** the card when opened.
- The AI **never holds a conversation**. At most one gentle inline follow-up
  (the calendar prompt).

## Non-goals (YAGNI)

- ❌ Live cinema showtimes — no free/reliable data source, especially in Portugal.
- ❌ Multi-turn AI conversation / agentic Q&A.
- ❌ Price tracking or alerts — price is a one-time snapshot.
- Only one media type (movie) ships now. `MediaInfo` is structured to extend to
  shows/books later without a schema change.

## Data model

Enrichment is stored as a single Codable struct attribute per host model — clean,
extensible, and migration-safe (one optional, mirrors the existing
`Link.thumbnailData` pattern). Images are cached as `Data` so they survive remote
URL expiry.

### `MediaInfo` (on `Note`)

```swift
public struct MediaInfo: Codable {
    public var tmdbID: Int
    public var title: String
    public var year: String?         // "2026"
    public var rating: Double?       // TMDB vote average, e.g. 7.4
    public var runtime: Int?         // minutes
    public var genre: String?        // primary genre name
    public var overview: String?     // synopsis
    public var posterData: Data?     // cached poster image
}
```

`Note` gains: `public var media: MediaInfo? = nil`
- When `media != nil`, the note renders enriched and shows the ✦ marker.
- `note.type` is unaffected; `media` presence drives enriched rendering.

### `ProductInfo` (on `Link`)

```swift
public struct ProductInfo: Codable {
    public var name: String
    public var brand: String?
    public var priceText: String?    // formatted, e.g. "€42.00"
    public var currency: String?     // ISO code when available
    public var availability: String? // e.g. "in stock"
    public var imageData: Data?      // cached product image
}
```

`Link` gains: `public var product: ProductInfo? = nil`
- When `product != nil`, the Library card shows the quiet `PRODUCT ✦` marker.
- A `LinkKind.product` case **is added** for detection/routing and aspect-ratio
  defaults; the enriched rendering keys off `product != nil`.

## Services

### TMDBService (new)

- `search(query:) async -> MediaInfo?` — TMDB `/search/movie`, take the best
  match, then `/movie/{id}` for details and poster path.
- Poster image downloaded and cached into `MediaInfo.posterData` (reuse the
  existing image-download helper in `LinkMetadataService`, or a shared utility).
- API key stored in `Secrets` alongside the Anthropic key (free TMDB key,
  registered once). Missing key → returns nil (graceful).

### NoteProcessor (classify extension)

- Extend the existing single classify call's JSON with an optional `media`
  field: `{ "kind": "movie", "query": "Obsession" }` when the text implies
  watching/consuming a titled work; null otherwise.
- `createNote` fires an async TMDB fill when `media.kind == "movie"`, populating
  `note.media`. Detection of a date (e.g. "saturday") continues to flow through
  the existing event-extraction path, so the calendar prompt appears.
- One API call total — no added latency.

### LinkMetadataService (product extension)

- Add product detection + parse: JSON-LD `schema.org/Product`
  (`<script type="application/ld+json">`), plus `og:type=product` and
  `product:price:amount` / `og:price:amount` meta tags.
- Add a small number of curated retailer fallbacks for major stores that don't
  expose clean structured data.
- On match, populate `Link.product` (download/cache the product image into
  `imageData`) and set `kind = .product`.

## UI

### Mind feed (movie)
- `NoteCard`: when `note.media != nil`, show a quiet ✦ next to the title. No
  other change — title + subtitle ("tap to open"). Feed remains calm.
- `NoteDetailSheet`: add a movie hero at the top — cached poster,
  `year · ★rating · runtime · genre`, overview. The existing inline `📅 add`
  calendar prompt (EventKit) sits below it.

### Library (product)
- `LinkCard`: when `link.product != nil`, show a quiet `PRODUCT ✦` marker. No
  price on the card.
- `LinkDetailPeek`: add a product section inside — cached image, price, brand,
  availability, and the open-link button.

### Quiet pills (related polish)
- Retune `PlatformPill` (currently too saturated/bright on Library cards) to a
  muted, low-saturation treatment. The new product marker uses the same quiet
  styling. This is a small standalone change bundled with this work.

## Error handling & fallbacks

Capture is never blocked; a thought or link is never lost.

- TMDB miss / no API key → note stays plain text, no ✦.
- Product scrape miss → stays an ordinary link.
- Image download failure → text-only enriched card (no image).
- All enrichment runs async off the capture path, best-effort.

## Testing

- `MediaInfo` / `ProductInfo` Codable round-trip.
- NoteProcessor classify: media field parsed; null when absent; capture still
  succeeds on malformed/empty media.
- TMDBService: search hit, miss, missing key, network failure → nil.
- LinkMetadataService product parse: JSON-LD present, OG-only, neither (plain
  link), malformed JSON-LD.
- Migration: existing stores load with new optional fields nil.
- UI: ✦ marker shows only when enrichment present; detail renders poster/product
  with and without cached image.

## Out of scope for this spec

Showtimes, price tracking, conversational AI, additional media types (shows,
books) — explicitly deferred. The data model leaves room for media types but
this implementation ships movies only.
