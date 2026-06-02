// MediaInfo.swift — AI-gathered enrichment for a media note (currently movies).
// Stored as a single Codable attribute on Note. All fields optional except the
// identifier/title so partial TMDB data still renders.

import Foundation

public struct MediaInfo: Codable, Equatable {
    public var tmdbID: Int
    public var title: String
    public var year: String?      // "2026"
    public var rating: Double?    // TMDB vote average, e.g. 7.4
    public var runtime: Int?      // minutes
    public var genre: String?     // primary genre name
    public var overview: String?  // synopsis
    public var posterData: Data?  // cached poster image bytes

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
