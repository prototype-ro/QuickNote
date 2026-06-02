// EmbeddingService.swift — on-device semantic embeddings via NaturalLanguage.
// Zero network, zero cost, works offline. Powers contextual resurfacing.

import Foundation
import NaturalLanguage

/// Produces fixed-length semantic vectors for note text, entirely on-device, in
/// the note's own language.
///
/// Vectors from different language models live in different spaces and must not be
/// compared, so `embed` also returns the language code; callers compare only within
/// the same language (see `SemanticIndex` usage).
public final class EmbeddingService {
    public static let shared = EmbeddingService()

    /// Cache of per-language sentence-embedding models (loading one is expensive).
    private var models: [NLLanguage: NLEmbedding] = [:]
    private let recognizer = NLLanguageRecognizer()
    private let lock = NSLock()

    public init() {}

    /// The language the embeddings ultimately fall back to when a note's own
    /// language has no on-device model.
    private static let fallback: NLLanguage = .english

    /// Detects the dominant language of `text`, returning `.english` when unsure.
    public func detectLanguage(of text: String) -> NLLanguage {
        lock.lock(); defer { lock.unlock() }
        recognizer.reset()
        recognizer.processString(text)
        return recognizer.dominantLanguage ?? Self.fallback
    }

    /// Returns the cached model for `language`, loading it on first use. Falls back
    /// to English if the language has no available sentence-embedding model.
    private func model(for language: NLLanguage) -> (model: NLEmbedding, language: NLLanguage)? {
        lock.lock(); defer { lock.unlock() }
        if let cached = models[language] { return (cached, language) }
        if let m = NLEmbedding.sentenceEmbedding(for: language) {
            models[language] = m
            return (m, language)
        }
        // Fall back to English so non-supported languages still get *a* vector.
        if let cached = models[Self.fallback] { return (cached, Self.fallback) }
        if let m = NLEmbedding.sentenceEmbedding(for: Self.fallback) {
            models[Self.fallback] = m
            return (m, Self.fallback)
        }
        return nil
    }

    /// Whether at least the fallback model is available on this device.
    public var isAvailable: Bool {
        NLEmbedding.sentenceEmbedding(for: Self.fallback) != nil
    }

    /// Embeds `text` in its detected language. Returns the vector and the language
    /// code actually used (so vectors are only ever compared within one space).
    public func embed(_ text: String) -> (vector: [Double], language: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ([], "") }
        let detected = detectLanguage(of: trimmed)
        guard let resolved = model(for: detected) else { return ([], "") }
        let vector = resolved.model.vector(for: trimmed) ?? []
        return (vector, resolved.language.rawValue)
    }
}
