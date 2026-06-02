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
