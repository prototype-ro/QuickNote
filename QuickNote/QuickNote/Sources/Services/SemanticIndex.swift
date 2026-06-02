// SemanticIndex.swift — cosine similarity + top-k retrieval over a note corpus.
// Pure value-type math, no persistence beyond Note.embedding.

import Foundation

/// Semantic retrieval helpers operating over an in-memory corpus of notes.
///
/// All inputs are precomputed embeddings (`Note.embedding` or a query vector
/// from `EmbeddingService`); this type does no embedding itself.
public enum SemanticIndex {

    /// Cosine similarity in `[-1, 1]`. Returns 0 for empty or mismatched vectors.
    public static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard !a.isEmpty, a.count == b.count else { return 0 }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in a.indices {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (sqrt(normA) * sqrt(normB))
    }

    /// The single most similar note to `vector` among `candidates` whose score
    /// meets `threshold`. Returns `nil` when nothing clears the bar (silence is
    /// the default — precision over recall).
    public static func bestMatch(
        to vector: [Double],
        among candidates: [Note],
        threshold: Double
    ) -> (note: Note, score: Double)? {
        guard !vector.isEmpty else { return nil }
        let scored = candidates
            .filter { !$0.embedding.isEmpty }
            .map { (note: $0, score: cosine(vector, $0.embedding)) }
            .filter { $0.score >= threshold }
        return scored.max { $0.score < $1.score }
    }

    /// The `k` most similar notes to `vector`, highest score first. Notes without
    /// embeddings are skipped. No threshold — used for pull-based recall where the
    /// user explicitly asked.
    public static func topK(
        _ k: Int,
        to vector: [Double],
        among candidates: [Note]
    ) -> [(note: Note, score: Double)] {
        guard !vector.isEmpty, k > 0 else { return [] }
        return candidates
            .filter { !$0.embedding.isEmpty }
            .map { (note: $0, score: cosine(vector, $0.embedding)) }
            .sorted { $0.score > $1.score }
            .prefix(k)
            .map { $0 }
    }

    /// Component-wise mean of the given embeddings, ignoring empty ones. Used to
    /// form a "recent captures" centroid for digest resurfacing.
    public static func centroid(of embeddings: [[Double]]) -> [Double] {
        let valid = embeddings.filter { !$0.isEmpty }
        guard let dim = valid.first?.count, dim > 0 else { return [] }
        var sum = [Double](repeating: 0, count: dim)
        var count = 0
        for vec in valid where vec.count == dim {
            for i in 0..<dim { sum[i] += vec[i] }
            count += 1
        }
        guard count > 0 else { return [] }
        return sum.map { $0 / Double(count) }
    }
}
