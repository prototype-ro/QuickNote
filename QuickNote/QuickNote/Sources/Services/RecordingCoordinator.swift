import Foundation
import Observation

/// Owns the single active voice recording, decoupled from any view so it survives
/// backgrounding and is reachable by the Live Activity + lock-screen Stop intent.
@MainActor
@Observable
public final class RecordingCoordinator {
    public static let shared = RecordingCoordinator()

    private let recorder = AudioRecorderService()

    public var state: AudioRecorderService.State { recorder.state }
    public var elapsed: TimeInterval { recorder.elapsed }
    public var level: CGFloat { recorder.level }
    public var selectedDrill: RoteiroDrill?

    /// Set by the app layer to persist a finished recording into the feed.
    public var onFinish: ((_ fileName: String, _ duration: TimeInterval, _ waveform: [Float], _ drill: RoteiroDrill?) -> Void)?

    /// Hooks the Live Activity layer sets later (nil-safe for now).
    public var onStartActivity: (() -> Void)?
    public var onEndActivity: (() -> Void)?

    private init() {}

    public func start() async {
        await recorder.start()
        if recorder.state == .recording { onStartActivity?() }
    }

    public func stop() {
        let result = recorder.stop()
        onEndActivity?()
        if let result {
            onFinish?(result.fileName, result.duration, result.waveform, selectedDrill)
        }
        selectedDrill = nil
    }

    public func cancel() {
        recorder.cancel()
        onEndActivity?()
        selectedDrill = nil
    }

    /// Test seam — exercises the onFinish wiring without real audio.
    func deliverFinishForTesting(fileName: String, duration: TimeInterval, waveform: [Float], drill: RoteiroDrill?) {
        onFinish?(fileName, duration, waveform, drill)
    }
}
