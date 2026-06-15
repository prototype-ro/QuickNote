import AppIntents
import Foundation

/// Lock-screen / Dynamic Island Stop button. Add this file to BOTH target
/// memberships (the widget references the type; `perform` runs in the app process).
/// Kept free of app-only types — it just posts a notification the app observes —
/// so it compiles cleanly inside the widget extension.
public struct StopRecordingIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Parar gravação"
    public init() {}
    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .stopRecordingRequested, object: nil)
        }
        return .result()
    }
}

public extension Notification.Name {
    /// Posted by the lock-screen Stop intent; the app's RecordingCoordinator observes it.
    static let stopRecordingRequested = Notification.Name("stopRecordingRequested")
}
