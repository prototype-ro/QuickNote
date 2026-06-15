import Foundation

/// A colored timestamp the user drops while reviewing a voice recording.
public struct VoiceMark: Codable, Equatable, Identifiable {
    public var id: UUID
    public var time: Double      // seconds into the recording
    public var colorIndex: Int   // index into StampPalette.colors
    public var label: String

    public init(id: UUID = UUID(), time: Double, colorIndex: Int = 0, label: String = "") {
        self.id = id
        self.time = time
        self.colorIndex = colorIndex
        self.label = label
    }
}
