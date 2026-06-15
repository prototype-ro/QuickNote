import Foundation
import Observation
import ActivityKit

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

    private var activity: Activity<RecordingActivityAttributes>?
    private var activityTimer: Timer?
    private var recentLevels: [Double] = []

    private init() {
        // The lock-screen Stop intent posts this; stop the active recording.
        NotificationCenter.default.addObserver(forName: .stopRecordingRequested, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
        // A prior run may have been killed mid-recording (or the Stop intent cold-launched
        // us); clear any orphaned activity so the lock screen doesn't show a stale card.
        endStaleActivities()
    }

    public func start() async {
        await recorder.start()
        if recorder.state == .recording { startActivity() }
    }

    public func stop() {
        let result = recorder.stop()
        endActivity()
        if let result {
            onFinish?(result.fileName, result.duration, result.waveform, selectedDrill)
        }
        selectedDrill = nil
    }

    public func cancel() {
        recorder.cancel()
        endActivity()
        selectedDrill = nil
    }

    // MARK: - Live Activity

    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let title = selectedDrill?.label ?? "gravação"
        let initial = RecordingActivityAttributes.ContentState(elapsed: 0, levels: [])
        do {
            activity = try Activity.request(
                attributes: RecordingActivityAttributes(title: title),
                content: .init(state: initial, staleDate: nil))
        } catch {
            activity = nil
        }
        activityTimer?.invalidate()
        guard activity != nil else { return }   // request failed → no point ticking
        activityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pushActivityUpdate() }
        }
    }

    /// Ends any Live Activity left over from a previous app run.
    private func endStaleActivities() {
        Task {
            for activity in Activity<RecordingActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func pushActivityUpdate() {
        guard let activity else { return }
        recentLevels.append(Double(level))
        if recentLevels.count > 16 { recentLevels.removeFirst(recentLevels.count - 16) }
        let state = RecordingActivityAttributes.ContentState(elapsed: elapsed, levels: recentLevels)
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    private func endActivity() {
        activityTimer?.invalidate()
        activityTimer = nil
        recentLevels = []
        let final = RecordingActivityAttributes.ContentState(elapsed: elapsed, levels: [])
        let ending = activity
        activity = nil
        Task { await ending?.end(.init(state: final, staleDate: nil), dismissalPolicy: .immediate) }
    }

    /// Test seam — exercises the onFinish wiring without real audio.
    func deliverFinishForTesting(fileName: String, duration: TimeInterval, waveform: [Float], drill: RoteiroDrill?) {
        onFinish?(fileName, duration, waveform, drill)
    }
}
