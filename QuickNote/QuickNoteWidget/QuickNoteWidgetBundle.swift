// QuickNoteWidgetBundle.swift — entry point for the widget extension target.

import WidgetKit
import SwiftUI

@main
struct QuickNoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        GlanceWidget()
        CaptureWidget()
    }
}
