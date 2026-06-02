// GlanceWidget.swift — home-screen + StandBy widget: latest thought and count.
// Tap opens the inbox.

import WidgetKit
import SwiftUI

struct GlanceWidget: Widget {
    let kind = "QuickNoteGlance"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickNoteProvider()) { entry in
            GlanceView(entry: entry)
                .containerBackground(WidgetTheme.background, for: .widget)
                .widgetURL(WidgetRoute.inbox)
        }
        .configurationDisplayName("Your Mind")
        .description("Your latest thought, at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct GlanceView: View {
    let entry: QuickNoteEntry
    @Environment(\.widgetFamily) private var family

    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var isEmpty: Bool { snapshot.count == 0 || snapshot.latestText.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                WidgetMark(size: 18)
                Spacer()
                Text("\(snapshot.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.secondary)
                + Text(snapshot.count == 1 ? " thought" : " thoughts")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(WidgetTheme.tertiary)
            }

            Spacer(minLength: 8)

            if isEmpty {
                Text("leave a thought.")
                    .font(.system(size: family == .systemSmall ? 15 : 17, weight: .light))
                    .italic()
                    .foregroundStyle(WidgetTheme.tertiary)
            } else {
                Text(snapshot.latestType.uppercased())
                    .font(.system(size: 9.5, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(WidgetTheme.secondary)
                    .padding(.bottom, 3)
                Text(snapshot.latestText)
                    .font(.system(size: family == .systemSmall ? 14 : 16, weight: .light))
                    .tracking(-0.1)
                    .lineSpacing(2)
                    .foregroundStyle(WidgetTheme.primary)
                    .lineLimit(family == .systemSmall ? 3 : 4)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
