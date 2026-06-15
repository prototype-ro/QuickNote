import ActivityKit
import Foundation

/// Shared between the app (which starts/updates/ends the activity) and the widget
/// extension (which renders it). Add this file to BOTH target memberships.
/// Pure ActivityKit — no app-only dependencies — so it compiles in either target.
public struct RecordingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var elapsed: TimeInterval
        public var levels: [Double]   // recent mic levels (0...1) for a waveform motif
        public init(elapsed: TimeInterval, levels: [Double]) {
            self.elapsed = elapsed
            self.levels = levels
        }
    }

    public var title: String          // drill label or "gravação"
    public init(title: String) { self.title = title }
}
