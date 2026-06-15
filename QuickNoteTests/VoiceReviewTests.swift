import Testing
@testable import QuickNote

struct VoiceReviewTests {
    @Test func codableRoundTrip() throws {
        let r = VoiceReview(fillerCount: 4, pace: "bom", improved: "respirei mais", focusNext: "menos 'tipo'")
        let data = try JSONEncoder().encode(r)
        let back = try JSONDecoder().decode(VoiceReview.self, from: data)
        #expect(back == r)
    }
    @Test func emptyDetection() {
        #expect(VoiceReview().isEmpty)
        #expect(!VoiceReview(fillerCount: 1).isEmpty)
    }
    @Test func drillLabel() {
        #expect(RoteiroDrill.monologo.label == "monólogo cronometrado")
        #expect(RoteiroDrill(rawValue: "camera") == .camera)
    }
}
