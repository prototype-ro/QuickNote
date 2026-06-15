import Foundation
import AVFoundation
import Observation

/// Plays one recording at a time; publishes play state + progress for the card
/// and detail to share (only one note plays at once).
@Observable
public final class AudioPlayerService: NSObject, AVAudioPlayerDelegate {
    public private(set) var isPlaying = false
    public private(set) var progress: Double = 0
    public private(set) var currentTime: TimeInterval = 0
    public private(set) var playingFileName: String?

    private var player: AVAudioPlayer?
    private var timer: Timer?

    public func toggle(fileName: String) {
        if isPlaying && playingFileName == fileName { pause() } else { play(fileName: fileName) }
    }

    public func play(fileName: String) {
        if playingFileName != fileName { stop() }
        let url = RecordingsDirectory.url(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try player ?? AVAudioPlayer(contentsOf: url)
            p.delegate = self
            player = p; playingFileName = fileName
            p.play(); isPlaying = true; startTimer()
        } catch { isPlaying = false }
    }

    public func pause() { player?.pause(); isPlaying = false; stopTimer() }

    public func stop() {
        player?.stop(); player = nil; isPlaying = false
        progress = 0; currentTime = 0; playingFileName = nil; stopTimer()
    }

    public func seek(toFraction f: Double) {
        guard let p = player else { return }
        p.currentTime = f * p.duration; currentTime = p.currentTime; progress = f
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self, let p = self.player, p.duration > 0 else { return }
            self.currentTime = p.currentTime
            self.progress = p.currentTime / p.duration
        }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Fully reset so the same recording can be replayed (leaving the player
        // parked at end-of-file makes a second play() a no-op).
        stop()
    }
}
