import Testing
import SwiftUI
@testable import QuickNote

struct VoiceMarkTests {
    @Test func codableRoundTrip() throws {
        let m = VoiceMark(time: 12.5, colorIndex: 3, label: "boa pausa")
        let back = try JSONDecoder().decode(VoiceMark.self, from: JSONEncoder().encode(m))
        #expect(back.time == m.time && back.colorIndex == m.colorIndex && back.label == m.label)
    }
    @Test func paletteHasSixColors() {
        #expect(StampPalette.colors.count == 6)
    }
    @Test func colorIndexClamps() {
        #expect(StampPalette.color(for: 99) == StampPalette.colors[0])
        #expect(StampPalette.color(for: -1) == StampPalette.colors[0])
        #expect(StampPalette.color(for: 2) == StampPalette.colors[2])
    }
}
