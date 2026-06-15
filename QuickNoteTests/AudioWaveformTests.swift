import Testing
@testable import QuickNote

struct AudioWaveformTests {
    @Test func downsampleProducesRequestedBarCount() {
        let raw: [Float] = (0..<1000).map { Float($0) / 1000 }
        let peaks = WaveformSampler.downsample(raw, to: 48)
        #expect(peaks.count == 48)
        #expect(peaks.allSatisfy { $0 >= 0 && $0 <= 1 })
        #expect(peaks.last! > peaks.first!)
    }
    @Test func downsampleHandlesShortInput() {
        let peaks = WaveformSampler.downsample([0.5, 0.9], to: 48)
        #expect(peaks.count == 48)
    }
    @Test func downsampleEmptyIsAllZero() {
        let peaks = WaveformSampler.downsample([], to: 48)
        #expect(peaks == [Float](repeating: 0, count: 48))
    }
}
