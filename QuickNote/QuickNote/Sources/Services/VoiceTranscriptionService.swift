import Foundation
import Speech

/// On-device transcription of a saved recording file. Separate from the live
/// dictation in VoiceCaptureManager — this reads a finished .m4a on demand.
public enum VoiceTranscriptionService {
    public enum TranscribeError: Error { case unavailable, noSpeech, failed }

    public static var isAvailable: Bool {
        SFSpeechRecognizer(locale: Locale.current)?.isAvailable
            ?? SFSpeechRecognizer()?.isAvailable ?? false
    }

    private static func authorize() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }

    /// Transcribes the recording named `fileName` in Documents/Recordings/.
    public static func transcribe(fileName: String) async throws -> String {
        guard await authorize() else { throw TranscribeError.unavailable }
        let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else { throw TranscribeError.unavailable }
        recognizer.defaultTaskHint = .dictation
        let url = RecordingsDirectory.url(for: fileName)
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                if let error { cont.resume(throwing: error); return }
                guard let result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    cont.resume(throwing: TranscribeError.noSpeech)
                } else {
                    cont.resume(returning: text)
                }
            }
        }
    }
}
