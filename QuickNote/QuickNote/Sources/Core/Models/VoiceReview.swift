// VoiceReview.swift — speech-practice review loop + drill tag for voice notes.
// Stored as one Codable attribute on Note (mirrors MediaInfo). UI maps the
// `pace`/`drill` strings to the enums below.

import Foundation

public struct VoiceReview: Codable, Equatable {
    public var fillerCount: Int?   // "tipo / né / então"
    public var pace: String?       // RecordingPace rawValue
    public var improved: String    // 1 coisa que melhorou
    public var focusNext: String   // 1 coisa pra focar

    public init(fillerCount: Int? = nil, pace: String? = nil,
                improved: String = "", focusNext: String = "") {
        self.fillerCount = fillerCount
        self.pace = pace
        self.improved = improved
        self.focusNext = focusNext
    }

    public var isEmpty: Bool {
        fillerCount == nil && pace == nil &&
        improved.trimmingCharacters(in: .whitespaces).isEmpty &&
        focusNext.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

public enum RecordingPace: String, Codable, CaseIterable, Identifiable {
    case lento, bom, rapido
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .lento:  return "lento"
        case .bom:    return "no ponto"
        case .rapido: return "acelerado"
        }
    }
}

public enum RoteiroDrill: String, Codable, CaseIterable, Identifiable {
    case leitura, narracao, monologo, recontar, debate, storytelling, riff, camera, shadowing
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .leitura:      return "leitura em voz alta"
        case .narracao:     return "narração"
        case .monologo:     return "monólogo cronometrado"
        case .recontar:     return "recontar"
        case .debate:       return "debate consigo"
        case .storytelling: return "storytelling"
        case .riff:         return "riff / observação"
        case .camera:       return "explica pra câmera"
        case .shadowing:    return "shadowing"
        }
    }
}
