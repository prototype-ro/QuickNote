// CaptureWidget.swift — lock-screen accessories: a one-tap path into capture.
// Tap opens the app with the capture bar focused.

import WidgetKit
import SwiftUI

struct CaptureWidget: Widget {
    let kind = "QuickNoteCapture"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickNoteProvider()) { entry in
            CaptureAccessoryView(entry: entry)
                .widgetURL(WidgetRoute.capture)
        }
        .configurationDisplayName("Capture")
        .description("Leave a thought from your lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct CaptureAccessoryView: View {
    let entry: QuickNoteEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                WidgetMark(size: 22, color: .primary)
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                WidgetMark(size: 20, color: .primary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("capture")
                        .font(.system(size: 15, weight: .semibold))
                    Text(countLine)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        case .accessoryInline:
            Label("capture a thought", systemImage: "square.dashed")
        default:
            WidgetMark(size: 22, color: .primary)
        }
    }

    private var countLine: String {
        let c = entry.snapshot.count
        return c == 0 ? "your mind awaits" : "\(c) thought\(c == 1 ? "" : "s") held"
    }
}
