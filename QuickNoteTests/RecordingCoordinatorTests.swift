import Testing
@testable import QuickNote

@MainActor
struct RecordingCoordinatorTests {
    @Test func idleByDefault() {
        let c = RecordingCoordinator.shared
        #expect(c.state == .idle)
    }
    @Test func onFinishStoresCallback() {
        let c = RecordingCoordinator.shared
        var called = false
        c.onFinish = { _, _, _, _ in called = true }
        c.deliverFinishForTesting(fileName: "a.m4a", duration: 1, waveform: [0.1], drill: nil)
        #expect(called)
    }
}
