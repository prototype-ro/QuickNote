// WidgetProvider.swift — timeline + shared visual tokens for QuickNote widgets.
//
// Reads the app-group snapshot written by WidgetBridge. The app calls
// WidgetCenter.reloadAllTimelines() on every corpus change, so entries stay fresh;
// the 30-minute refresh below is only a fallback.

import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct QuickNoteEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

// MARK: - Provider

struct QuickNoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickNoteEntry {
        QuickNoteEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickNoteEntry) -> Void) {
        completion(QuickNoteEntry(date: Date(), snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickNoteEntry>) -> Void) {
        let entry = QuickNoteEntry(date: Date(), snapshot: WidgetSnapshot.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Visual tokens (widget-local, mirrors the app design system)

enum WidgetTheme {
    static let background = Color(red: 0.941, green: 0.949, blue: 0.957) // #F0F2F4
    static let primary = Color(red: 0.039, green: 0.039, blue: 0.043)    // #0A0A0B
    static let secondary = Color(red: 0.420, green: 0.447, blue: 0.502)  // #6B7280
    static let tertiary = Color(red: 0.612, green: 0.639, blue: 0.686)   // #9CA3AF
    static let accent = Color(red: 0.478, green: 0.654, blue: 1.0)       // #7AA7FF
}

/// The QuickNote mark — a rounded square with an open corner. Widget-local copy
/// so the extension needn't depend on the app's DesignSystem.
struct WidgetMark: View {
    var size: CGFloat = 22
    var stroke: CGFloat = 1.6
    var color: Color = WidgetTheme.primary

    var body: some View {
        Canvas { ctx, sz in
            let inset = stroke / 2
            let rect = CGRect(x: inset, y: inset, width: sz.width - stroke, height: sz.height - stroke)
            let r = sz.width * 0.28
            var path = Path()
            // Open top-right corner — the "thought escaping" mark.
            path.move(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
                        startAngle: .degrees(-90), endAngle: .degrees(180), clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
                        startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                        startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + r * 1.6))
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: stroke, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}
