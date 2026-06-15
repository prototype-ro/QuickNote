import Testing
@testable import QuickNote

struct NoteVoiceTests {
    @Test func isVoiceAndTranscribed() {
        let n = Note(rawText: "", type: .voice)
        n.audioFileName = "a.m4a"; n.audioDuration = 5
        #expect(n.isVoice)
        #expect(!n.isTranscribed)
        n.rawText = "olá mundo"
        #expect(n.isTranscribed)
    }
    @Test func nonVoiceNeverTranscribedFlag() {
        let n = Note(rawText: "hi", type: .note)
        #expect(!n.isVoice)
        #expect(!n.isTranscribed)
    }
}
