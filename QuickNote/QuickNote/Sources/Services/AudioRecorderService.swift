import Foundation
import AVFoundation
import Observation

/// Pure downsampling of a live amplitude buffer into a fixed number of peaks.
public enum WaveformSampler {
    public static func downsample(_ samples: [Float], to bars: Int) -> [Float] {
        guard bars > 0 else { return [] }
        guard !samples.isEmpty else { return [Float](repeating: 0, count: bars) }
        var out = [Float](repeating: 0, count: bars)
        let bucket = Double(samples.count) / Double(bars)
        for i in 0..<bars {
            let lo = Int(Double(i) * bucket)
            let hi = max(lo + 1, Int(Double(i + 1) * bucket))
            let slice = samples[min(lo, samples.count - 1)..<min(hi, samples.count)]
            out[i] = slice.max() ?? 0
        }
        return out
    }
}

@Observable
public final class AudioRecorderService: NSObject {
    public enum State { case idle, recording, denied }
    public private(set) var state: State = .idle
    public private(set) var level: CGFloat = 0
    public private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var startDate: Date?
    private var currentFileName: String?
    private var levelBuffer: [Float] = []

    public func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
    }

    public func start() async {
        guard await requestPermission() else { state = .denied; return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch { return }

        let fileName = "\(UUID().uuidString).m4a"
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let rec = try AVAudioRecorder(url: RecordingsDirectory.url(for: fileName), settings: settings)
            rec.isMeteringEnabled = true
            rec.record()
            recorder = rec
            currentFileName = fileName
            startDate = .now
            levelBuffer = []
            state = .recording
            startMetering()
            NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)),
                name: AVAudioSession.interruptionNotification, object: nil)
        } catch { state = .idle }
    }

    /// Stops and returns the saved file name, duration, and downsampled waveform.
    @discardableResult
    public func stop(bars: Int = 48) -> (fileName: String, duration: TimeInterval, waveform: [Float])? {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        guard let rec = recorder, let name = currentFileName else { return nil }
        let duration = rec.currentTime
        rec.stop()
        stopMetering()
        let waveform = WaveformSampler.downsample(levelBuffer, to: bars)
        recorder = nil; currentFileName = nil; state = .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return (name, max(duration, 0), waveform)
    }

    public func cancel() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        guard let rec = recorder, let name = currentFileName else { return }
        rec.stop(); rec.deleteRecording()
        RecordingsDirectory.remove(name)
        stopMetering()
        recorder = nil; currentFileName = nil; state = .idle
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began {
            // Save what we have rather than risk losing audio.
            Task { @MainActor in RecordingCoordinator.shared.stop() }
        }
    }

    private func startMetering() {
        elapsed = 0
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let rec = self.recorder else { return }
            rec.updateMeters()
            let power = rec.averagePower(forChannel: 0)        // -160...0 dB
            let normalized = CGFloat(max(0, (power + 50) / 50)) // floor at -50 dB
            self.level = min(1, normalized)
            self.levelBuffer.append(Float(self.level))
            if let s = self.startDate { self.elapsed = Date.now.timeIntervalSince(s) }
        }
    }

    private func stopMetering() { meterTimer?.invalidate(); meterTimer = nil; level = 0 }
}
