import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct QuickNoteRecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // Lock screen / banner
            HStack(spacing: 12) {
                Circle().fill(.red).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title).font(.caption.weight(.medium))
                    MiniWave(levels: context.state.levels).frame(height: 14)
                }
                Spacer()
                Text(elapsedString(context.state.elapsed))
                    .font(.system(.title3, design: .rounded).monospacedDigit())
                Button(intent: StopRecordingIntent()) {
                    Image(systemName: "stop.fill").foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.6))
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Circle().fill(.red).frame(width: 10, height: 10)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(elapsedString(context.state.elapsed)).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        MiniWave(levels: context.state.levels).frame(height: 16)
                        Button(intent: StopRecordingIntent()) {
                            Image(systemName: "stop.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } compactLeading: {
                Circle().fill(.red).frame(width: 8, height: 8)
            } compactTrailing: {
                Text(elapsedString(context.state.elapsed)).monospacedDigit().font(.caption2)
            } minimal: {
                Circle().fill(.red).frame(width: 8, height: 8)
            }
        }
    }
}

private func elapsedString(_ t: TimeInterval) -> String {
    let s = Int(t)
    return String(format: "%02d:%02d", s / 60, s % 60)
}

/// A small animated waveform motif from periodic levels (not a real-time meter).
struct MiniWave: View {
    let levels: [Double]
    var body: some View {
        GeometryReader { geo in
            let n = max(levels.count, 1)
            let w = max(1.5, (geo.size.width - CGFloat(n) * 2) / CGFloat(n))
            HStack(alignment: .center, spacing: 2) {
                ForEach(levels.indices, id: \.self) { i in
                    Capsule().fill(.white.opacity(0.85))
                        .frame(width: w, height: max(2, CGFloat(levels[i]) * geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
