# Voice Capture Type Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add **voice** as a fifth first-class capture type that lives natively in the existing SwiftData `Note` feed — record audio, annotate it, optionally transcribe it into the corpus.

**Architecture:** Extend `NoteType` with `.voice` and add optional, migration-safe fields to `Note` (audio file name, duration, real waveform peaks, drill tag, `VoiceReview`, annotation). Recording/playback are two `@Observable` services in `Sources/Services/`; the player is shared via `.environment`. A dedicated capture sheet inserts a `Note(type: .voice)` straight into the feed. Detail gets a sage voice-hero (mirroring the existing movie-hero) with an on-demand transcribe button that fills the note text and embeds it.

**Tech Stack:** SwiftUI, SwiftData, AVFoundation (`AVAudioRecorder`/`AVAudioPlayer`), `SFSpeechRecognizer` (file-based), existing `EmbeddingService` / `CategoryTint` / `PolishKit`.

**Spec:** `docs/superpowers/specs/2026-06-15-voice-capture-type-design.md`

---

## Testing reality (read first)

There is **no test target** in this project and `.pbxproj` is Xcode-managed (do not edit). Therefore:

- **Per-task gate = BUILD SUCCEEDED + targeted sim runtime check**, matching this project's established workflow. Build with:
  ```bash
  xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' build
  ```
  (Never use `-destination "id=…"` — it hangs on a device-probe bug. If a build stalls at ~0% CPU, `kill -9` the xcodebuild + clang and rebuild.)
- **Pure-logic units ship with Swift Testing code** in this plan. They are written to a `QuickNoteTests/` folder so they are ready the moment a test target exists. Creating that target is a **manual Xcode step (Task 0)** — until then the code compiles only inside the target and is not run by CI.

## File map

**Create:**
- `QuickNote/QuickNote/Sources/Services/AudioRecorderService.swift` — record + live level + waveform capture
- `QuickNote/QuickNote/Sources/Services/AudioPlayerService.swift` — single-player playback
- `QuickNote/QuickNote/Sources/Services/RecordingsDirectory.swift` — Documents/Recordings/ helper
- `QuickNote/QuickNote/Sources/Services/VoiceTranscriptionService.swift` — file-based SFSpeechRecognizer
- `QuickNote/QuickNote/Sources/Core/Models/VoiceReview.swift` — Codable review + `RoteiroDrill`
- `QuickNote/QuickNote/Sources/Features/Mind/VoiceCard.swift` — feed row
- `QuickNote/QuickNote/Sources/Features/Mind/CaptureRecordingSheet.swift` — capture sheet + waveform/level views
- `QuickNoteTests/AudioWaveformTests.swift`, `QuickNoteTests/VoiceReviewTests.swift`, `QuickNoteTests/NoteVoiceTests.swift` (test-target only)

**Modify:**
- `Sources/Core/Models/Note.swift` — `NoteType.voice` + iconName, new `Note` fields + computed
- `Sources/DesignSystem/PolishKit.swift:13-20` — `CategoryTint.wash(.voice)`
- `Sources/DesignSystem/Theme.swift` — sage `AppColors` tokens
- `Sources/Core/AppState.swift` — `isRecordingVoice` flag
- `Sources/Features/Mind/MindView.swift` — record affordance plumbing, sheet overlay, feed routing, insert-voice path
- `Sources/Features/Mind/NoteComponents.swift` — route `note.isVoice` → `VoiceCard`
- `Sources/Features/Mind/NoteDetailSheet.swift:88,245` — voice hero + annotation + transcribe + review
- `Sources/Features/Mind/CaptureBarView` (in MindView or its own file) — record button affordance
- `ContentView.swift:6-25` — inject shared `AudioPlayerService`
- `Sources/Services/ExportService.swift` — voice marker in Markdown

**Reuse from `/Users/rodgz_mac/Downloads/Voice Quicknote/`:** `AudioEngine.swift` (split into recorder/player/dir), `VoiceComponents.swift` (LevelBar, PlayerPanel, DrillChip, ReviewEditor), `VoiceNoteDetailView.swift` (hero/review layout), `CaptureRecordingSheet` body. **Drop:** `VoiceNote.swift` struct, `VoiceNoteStore.swift`, `VoiceNotesView.swift` (replaced by feed integration). Map `voiceTint`/`voiceTintSoft` onto real tokens.

---

## Task 0: Manual prerequisites (human, in Xcode)

**Files:** Info.plist (Xcode-managed), optional new test target.

- [ ] **Step 1: Add mic usage string**

In Xcode → app target → Info: add `NSMicrophoneUsageDescription` = `"Gravar suas notas de voz e exercícios de fala."`. `NSSpeechRecognitionUsageDescription` already exists (reused for transcription) — verify it's present.

- [ ] **Step 2 (optional, enables unit tests): create test target**

Xcode → File → New → Target → Unit Testing Bundle named `QuickNoteTests`. Add the `QuickNoteTests/*.swift` files to it. If skipped, the test files still compile-check nothing; rely on build + sim gates.

- [ ] **Step 3: Confirm app builds clean before changes**

Run: `xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' build`
Expected: `** BUILD SUCCEEDED **`

---

## Task 1: NoteType gains `.voice`

**Files:**
- Modify: `QuickNote/QuickNote/Sources/Core/Models/Note.swift:4-18`

- [ ] **Step 1: Add the case + icon**

In `enum NoteType`, add `voice`:
```swift
public enum NoteType: String, Codable, CaseIterable {
    case task, idea, note, link, digest, voice

    public var iconName: String {
        switch self {
        case .task:   return "checkmark.circle"
        case .idea:   return "lightbulb"
        case .note:   return "note.text"
        case .link:   return "link"
        case .digest: return "calendar"
        case .voice:  return "waveform"
        }
    }

    public var displayName: String { rawValue.uppercased() }
}
```

- [ ] **Step 2: Build (catches non-exhaustive switches elsewhere)**

Run: `xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' build`
Expected: build errors at any `switch type` lacking `.voice` (PolishKit handled in Task 6). Note them; they are fixed in later tasks. If only PolishKit's `CategoryTint` errors, that's expected — proceed; the build goes green after Task 6. To unblock building now, temporarily ensure `CategoryTint.wash` has `case .voice: return .clear` (finalized in Task 6).

- [ ] **Step 3: Commit**

```bash
git add QuickNote/QuickNote/Sources/Core/Models/Note.swift
git commit -m "feat(voice): add .voice case to NoteType"
```

---

## Task 2: Voice fields on Note + VoiceReview/RoteiroDrill

**Files:**
- Create: `QuickNote/QuickNote/Sources/Core/Models/VoiceReview.swift`
- Modify: `QuickNote/QuickNote/Sources/Core/Models/Note.swift` (add stored props after `langCode`, computed after `hasMedia`)
- Test: `QuickNoteTests/VoiceReviewTests.swift`, `QuickNoteTests/NoteVoiceTests.swift`

- [ ] **Step 1: Write the failing tests**

`QuickNoteTests/VoiceReviewTests.swift`:
```swift
import Testing
@testable import QuickNote

struct VoiceReviewTests {
    @Test func codableRoundTrip() throws {
        let r = VoiceReview(fillerCount: 4, pace: "bom", improved: "respirei mais", focusNext: "menos 'tipo'")
        let data = try JSONEncoder().encode(r)
        let back = try JSONDecoder().decode(VoiceReview.self, from: data)
        #expect(back == r)
    }

    @Test func emptyDetection() {
        #expect(VoiceReview().isEmpty)
        #expect(!VoiceReview(fillerCount: 1).isEmpty)
    }

    @Test func drillLabel() {
        #expect(RoteiroDrill.monologo.label == "monólogo cronometrado")
        #expect(RoteiroDrill(rawValue: "camera") == .camera)
    }
}
```

`QuickNoteTests/NoteVoiceTests.swift`:
```swift
import Testing
@testable import QuickNote

struct NoteVoiceTests {
    @Test func isVoiceAndTranscribed() {
        let n = Note(rawText: "", type: .voice)
        n.audioFileName = "a.m4a"; n.audioDuration = 5
        #expect(n.isVoice)
        #expect(!n.isTranscribed)
        n.rawText = "olá mundo"
        #expect(n.isTranscribed)
    }

    @Test func nonVoiceNeverTranscribedFlag() {
        let n = Note(rawText: "hi", type: .note)
        #expect(!n.isVoice)
        #expect(!n.isTranscribed)
    }
}
```

- [ ] **Step 2: Verify they fail (compile error: symbols undefined)**

Run (only if test target exists): `xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' test`
Expected: FAIL — `VoiceReview`, `RoteiroDrill`, `Note.isVoice`, `audioFileName` not found. (No target → skip; rely on build gate.)

- [ ] **Step 3: Create VoiceReview.swift**

```swift
// VoiceReview.swift — speech-practice review loop + drill tag for voice notes.
// Stored as one Codable attribute on Note (mirrors MediaInfo). UI maps the
// `pace`/`drill` strings to the enums below.

import Foundation

public struct VoiceReview: Codable, Equatable {
    public var fillerCount: Int?   // "tipo / né / então"
    public var pace: String?       // RecordingPace rawValue
    public var improved: String    // 1 coisa que melhorou
    public var focusNext: String   // 1 coisa pra focar

    public init(fillerCount: Int? = nil, pace: String? = nil,
                improved: String = "", focusNext: String = "") {
        self.fillerCount = fillerCount
        self.pace = pace
        self.improved = improved
        self.focusNext = focusNext
    }

    public var isEmpty: Bool {
        fillerCount == nil && pace == nil &&
        improved.trimmingCharacters(in: .whitespaces).isEmpty &&
        focusNext.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

public enum RecordingPace: String, Codable, CaseIterable, Identifiable {
    case lento, bom, rapido
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .lento:  return "lento"
        case .bom:    return "no ponto"
        case .rapido: return "acelerado"
        }
    }
}

public enum RoteiroDrill: String, Codable, CaseIterable, Identifiable {
    case leitura, narracao, monologo, recontar, debate, storytelling, riff, camera, shadowing
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .leitura:      return "leitura em voz alta"
        case .narracao:     return "narração"
        case .monologo:     return "monólogo cronometrado"
        case .recontar:     return "recontar"
        case .debate:       return "debate consigo"
        case .storytelling: return "storytelling"
        case .riff:         return "riff / observação"
        case .camera:       return "explica pra câmera"
        case .shadowing:    return "shadowing"
        }
    }
}
```

- [ ] **Step 4: Add stored props + computed to Note.swift**

After `public var langCode: String = ""` add:
```swift
    /// Relative file name of the recording inside Documents/Recordings/ (voice notes).
    public var audioFileName: String? = nil
    /// Recording length in seconds.
    public var audioDuration: Double = 0
    /// Real downsampled amplitude peaks (0...1), ~48 bars, for the static waveform.
    public var waveform: [Float] = []
    /// Optional roteiro drill tag (RoteiroDrill rawValue).
    public var drill: String? = nil
    /// Optional speech-practice review loop.
    public var voiceReview: VoiceReview? = nil
    /// Freeform "anotações sobre a gravação" (kept separate from AI `summary`).
    public var voiceAnnotation: String = ""
```
After `public var hasMedia: Bool { media != nil }` add:
```swift
    /// Whether this is a voice (audio) capture.
    public var isVoice: Bool { type == .voice }
    /// A voice note has been transcribed once its text body is populated.
    public var isTranscribed: Bool { isVoice && !rawText.isEmpty }
```

- [ ] **Step 5: Build (+ test if target exists)**

Run: `xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' build`
Expected: `** BUILD SUCCEEDED **` (migration-safe: all new props defaulted inline).

- [ ] **Step 6: Commit**

```bash
git add QuickNote/QuickNote/Sources/Core/Models/VoiceReview.swift QuickNote/QuickNote/Sources/Core/Models/Note.swift QuickNoteTests/VoiceReviewTests.swift QuickNoteTests/NoteVoiceTests.swift
git commit -m "feat(voice): add VoiceReview/RoteiroDrill + voice fields on Note"
```

---

## Task 3: AudioRecorderService + RecordingsDirectory (with real waveform)

**Files:**
- Create: `QuickNote/QuickNote/Sources/Services/RecordingsDirectory.swift`
- Create: `QuickNote/QuickNote/Sources/Services/AudioRecorderService.swift`
- Test: `QuickNoteTests/AudioWaveformTests.swift`

- [ ] **Step 1: Write the failing test (downsampling is the pure-logic unit)**

`QuickNoteTests/AudioWaveformTests.swift`:
```swift
import Testing
@testable import QuickNote

struct AudioWaveformTests {
    @Test func downsampleProducesRequestedBarCount() {
        let raw: [Float] = (0..<1000).map { Float($0) / 1000 }
        let peaks = WaveformSampler.downsample(raw, to: 48)
        #expect(peaks.count == 48)
        #expect(peaks.allSatisfy { $0 >= 0 && $0 <= 1 })
        #expect(peaks.last! > peaks.first!)   // rising signal stays rising
    }

    @Test func downsampleHandlesShortInput() {
        let peaks = WaveformSampler.downsample([0.5, 0.9], to: 48)
        #expect(peaks.count == 48)          // padded, never crashes
    }

    @Test func downsampleEmptyIsAllZero() {
        let peaks = WaveformSampler.downsample([], to: 48)
        #expect(peaks == [Float](repeating: 0, count: 48))
    }
}
```

- [ ] **Step 2: Verify fail** (`WaveformSampler` undefined). Skip if no target.

- [ ] **Step 3: RecordingsDirectory.swift**

```swift
import Foundation

/// On-disk location for voice recordings: Documents/Recordings/.
public enum RecordingsDirectory {
    public static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    public static func url(for fileName: String) -> URL {
        folder.appendingPathComponent(fileName)
    }
    public static func remove(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}
```

- [ ] **Step 4: AudioRecorderService.swift (recorder + WaveformSampler)**

```swift
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
        } catch { state = .idle }
    }

    /// Stops and returns the saved file name, duration, and downsampled waveform.
    @discardableResult
    public func stop(bars: Int = 48) -> (fileName: String, duration: TimeInterval, waveform: [Float])? {
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
        guard let rec = recorder, let name = currentFileName else { return }
        rec.stop(); rec.deleteRecording()
        RecordingsDirectory.remove(name)
        stopMetering()
        recorder = nil; currentFileName = nil; state = .idle
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
```

- [ ] **Step 5: Build (+ test)**

Run: `xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' build`
Expected: `** BUILD SUCCEEDED **`. If test target exists, `…test` → AudioWaveformTests PASS.

- [ ] **Step 6: Commit**

```bash
git add QuickNote/QuickNote/Sources/Services/RecordingsDirectory.swift QuickNote/QuickNote/Sources/Services/AudioRecorderService.swift QuickNoteTests/AudioWaveformTests.swift
git commit -m "feat(voice): recorder service with real waveform sampling"
```

---

## Task 4: AudioPlayerService + shared injection

**Files:**
- Create: `QuickNote/QuickNote/Sources/Services/AudioPlayerService.swift`
- Modify: `ContentView.swift:6-25`

- [ ] **Step 1: AudioPlayerService.swift**

```swift
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
        isPlaying = false; progress = 0; currentTime = 0; stopTimer()
    }
}
```

- [ ] **Step 2: Inject in ContentView**

Near `@State private var appState = AppState()` add `@State private var audioPlayer = AudioPlayerService()`. Add `.environment(audioPlayer)` next to each existing `.environment(appState)` (lines ~12, 17, 25).

- [ ] **Step 3: Build**

Run: `xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add QuickNote/QuickNote/Sources/Services/AudioPlayerService.swift QuickNote/QuickNote/ContentView.swift
git commit -m "feat(voice): shared audio player service via environment"
```

---

## Task 5: VoiceTranscriptionService (file-based, on-device)

**Files:**
- Create: `QuickNote/QuickNote/Sources/Services/VoiceTranscriptionService.swift`

- [ ] **Step 1: Implement**

```swift
import Foundation
import Speech

/// On-device transcription of a saved recording file. Separate from the live
/// dictation in VoiceCaptureManager — this reads a finished .m4a on demand.
public enum VoiceTranscriptionService {
    public enum TranscribeError: Error { case unavailable, noSpeech, failed }

    public static var isAvailable: Bool {
        SFSpeechRecognizer(locale: Locale.current)?.isAvailable
            ?? SFSpeechRecognizer()?.isAvailable ?? false
    }

    private static func authorize() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }

    /// Transcribes the recording named `fileName` in Documents/Recordings/.
    public static func transcribe(fileName: String) async throws -> String {
        guard await authorize() else { throw TranscribeError.unavailable }
        let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else { throw TranscribeError.unavailable }
        recognizer.defaultTaskHint = .dictation
        let url = RecordingsDirectory.url(for: fileName)
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                if let error { cont.resume(throwing: error); return }
                guard let result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    cont.resume(throwing: TranscribeError.noSpeech)
                } else {
                    cont.resume(returning: text)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add QuickNote/QuickNote/Sources/Services/VoiceTranscriptionService.swift
git commit -m "feat(voice): on-device file transcription service"
```

---

## Task 6: Sage tokens + CategoryTint.voice

**Files:**
- Modify: `Sources/DesignSystem/Theme.swift` (add tokens near other `AppColors`)
- Modify: `Sources/DesignSystem/PolishKit.swift:13-20`

- [ ] **Step 1: Add adaptive sage tokens in Theme.swift**

In `AppColors`, add (use the existing `Color.dynamic(light:dark:)` helper, matching siblings):
```swift
    /// Voice category — soft sage. Whisper wash on cards, accent on controls.
    static let voiceAccent = Color.dynamic(
        light: Color(red: 0.45, green: 0.58, blue: 0.45),
        dark:  Color(red: 0.62, green: 0.74, blue: 0.62))
```

- [ ] **Step 2: Add `.voice` to CategoryTint.wash**

```swift
        case .link:   return Color(red: 0.47, green: 0.62, blue: 0.95).opacity(0.07) // cool gray-blue
        case .voice:  return Color(red: 0.45, green: 0.58, blue: 0.45).opacity(0.07) // soft sage
        case .note, .digest: return .clear
```

- [ ] **Step 3: Build (NoteType switches now exhaustive)**

Run: `xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add QuickNote/QuickNote/Sources/DesignSystem/Theme.swift QuickNote/QuickNote/Sources/DesignSystem/PolishKit.swift
git commit -m "feat(voice): sage category tint + adaptive token"
```

---

## Task 7: Capture sheet + record affordance + insert into feed

**Files:**
- Create: `QuickNote/QuickNote/Sources/Features/Mind/CaptureRecordingSheet.swift`
- Modify: `Sources/Core/AppState.swift` (add flag)
- Modify: `Sources/Features/Mind/MindView.swift` (record button, sheet overlay, insert path)

- [ ] **Step 1: AppState flag**

In `AppState` add: `public var isRecordingVoice: Bool = false`.

- [ ] **Step 2: CaptureRecordingSheet.swift (drill chips, timer, live LevelBar, record button, shared subviews)**

```swift
import SwiftUI

// MARK: - Live mic level bar
struct LevelBar: View {
    let level: CGFloat
    private let bars = 28
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<bars, id: \.self) { i in
                    let threshold = CGFloat(i) / CGFloat(bars)
                    Capsule()
                        .fill(level >= threshold ? AppColors.voiceAccent : AppColors.ink.opacity(0.12))
                        .frame(width: max(2, (geo.size.width - CGFloat(bars) * 3) / CGFloat(bars)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.easeOut(duration: 0.08), value: level)
        }
    }
}

// MARK: - Drill chip (unified Pill style)
struct DrillChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .appFont(15, .medium)
                .foregroundStyle(selected ? AppColors.voiceAccent : AppColors.secondaryText)
                .padding(.vertical, 7).padding(.horizontal, 14)
                .background(Capsule().fill(selected
                    ? AppColors.voiceAccent.opacity(0.18)
                    : AppColors.ink.opacity(0.06)))
        }
        .buttonStyle(PressStyle())
    }
}

func qnTimeString(_ t: TimeInterval) -> String {
    let s = Int(t); return String(format: "%02d:%02d", s / 60, s % 60)
}

// MARK: - Capture sheet
struct CaptureRecordingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (_ fileName: String, _ duration: TimeInterval, _ waveform: [Float], _ drill: RoteiroDrill?) -> Void

    @State private var recorder = AudioRecorderService()
    @State private var selectedDrill: RoteiroDrill? = nil
    private var isRecording: Bool { recorder.state == .recording }

    var body: some View {
        VStack(spacing: 20) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    DrillChip(label: "livre", selected: selectedDrill == nil) { selectedDrill = nil }
                    ForEach(RoteiroDrill.allCases) { d in
                        DrillChip(label: d.label, selected: selectedDrill == d) { selectedDrill = d }
                    }
                }.padding(.horizontal, 16)
            }
            .disabled(isRecording).opacity(isRecording ? 0.4 : 1)

            Spacer(minLength: 0)
            Text(qnTimeString(recorder.elapsed))
                .appFont(36, .light, relativeTo: .largeTitle).monospacedDigit()
                .foregroundStyle(AppColors.primaryText)
            LevelBar(level: recorder.level).frame(height: 26).padding(.horizontal, 44)
            Spacer(minLength: 0)

            Button { Task { await toggle() } } label: {
                ZStack {
                    Circle().fill(isRecording ? Color(hex: "EF4444").opacity(0.14)
                                              : AppColors.voiceAccent.opacity(0.28))
                        .frame(width: 80, height: 80)
                    RoundedRectangle(cornerRadius: isRecording ? 7 : 28, style: .continuous)
                        .fill(isRecording ? Color(hex: "EF4444") : AppColors.primaryText)
                        .frame(width: isRecording ? 28 : 54, height: isRecording ? 28 : 54)
                        .motion(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRecording ? "parar gravação" : "iniciar gravação")

            if recorder.state == .denied {
                Text("acesso ao microfone negado — habilite em ajustes")
                    .appFont(13).foregroundStyle(AppColors.secondaryText)
            }
            Spacer(minLength: 6)
        }
        .padding(.top, 20)
    }

    private func toggle() async {
        switch recorder.state {
        case .idle, .denied: await recorder.start()
        case .recording:
            if let r = recorder.stop() {
                HapticEngine.submit()
                onSave(r.fileName, r.duration, r.waveform, selectedDrill)
                dismiss()
            }
        }
    }
}
```
(Note: `.motion(_:value:)` is the PolishKit Reduce-Motion helper. If its signature differs, use the existing helper as written in PolishKit.)

- [ ] **Step 3: Record affordance + sheet + insert in MindView**

In the capture-bar area (`MindView.swift` ~587) add a record button beside the bar that sets `appState.isRecordingVoice = true`. Add a sheet:
```swift
.sheet(isPresented: Binding(get: { appState.isRecordingVoice },
                            set: { appState.isRecordingVoice = $0 })) {
    CaptureRecordingSheet { fileName, duration, waveform, drill in
        insertVoiceNote(fileName: fileName, duration: duration, waveform: waveform, drill: drill)
    }
    .presentationDetents([.height(380)])
    .presentationDragIndicator(.visible)
}
```
Add the insert method near `submit()`:
```swift
private func insertVoiceNote(fileName: String, duration: TimeInterval,
                             waveform: [Float], drill: RoteiroDrill?) {
    let note = Note(rawText: "", type: .voice)   // empty body until transcribed
    note.audioFileName = fileName
    note.audioDuration = duration
    note.waveform = waveform
    note.drill = drill?.rawValue
    withAnimation(AppAnimation.springFluid) {
        latestNoteID = note.id
        modelContext.insert(note)
        HapticEngine.noteArrived()
    }
    Task { @MainActor in
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        latestNoteID = nil
    }
}
```

- [ ] **Step 4: Build + sim runtime check**

Run: `xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' build`
Expected: `** BUILD SUCCEEDED **`. Boot sim, open record affordance → sheet shows; record a few seconds → stop → a sage card appears in the feed.

- [ ] **Step 5: Commit**

```bash
git add QuickNote/QuickNote/Sources/Features/Mind/CaptureRecordingSheet.swift QuickNote/QuickNote/Sources/Core/AppState.swift QuickNote/QuickNote/Sources/Features/Mind/MindView.swift
git commit -m "feat(voice): capture sheet + record affordance inserts voice note into feed"
```

---

## Task 8: VoiceCard + feed routing

**Files:**
- Create: `QuickNote/QuickNote/Sources/Features/Mind/VoiceCard.swift`
- Modify: `Sources/Features/Mind/NoteComponents.swift` (route voice notes)

- [ ] **Step 1: VoiceCard.swift (real static waveform, played portion fills sage)**

```swift
import SwiftUI

struct StaticWaveform: View {
    let peaks: [Float]
    let progress: Double   // 0...1 played fraction
    var body: some View {
        GeometryReader { geo in
            let n = max(peaks.count, 1)
            let w = max(1.5, (geo.size.width - CGFloat(n) * 2) / CGFloat(n))
            HStack(alignment: .center, spacing: 2) {
                ForEach(peaks.indices, id: \.self) { i in
                    let played = Double(i) / Double(n) <= progress
                    Capsule()
                        .fill(played ? AppColors.voiceAccent : AppColors.voiceAccent.opacity(0.25))
                        .frame(width: w, height: max(3, CGFloat(peaks[i]) * geo.size.height))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

struct VoiceCard: View {
    let note: Note
    let onOpen: () -> Void
    @Environment(AudioPlayerService.self) private var player

    private var isThis: Bool { player.playingFileName == note.audioFileName }
    private var isPlaying: Bool { player.isPlaying && isThis }
    private var progress: Double { isThis ? player.progress : 0 }
    private var title: String {
        if note.isTranscribed { return note.displayText ?? note.rawText }
        if let d = note.drill, let drill = RoteiroDrill(rawValue: d) { return drill.label }
        return "gravação"
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Button {
                    if let f = note.audioFileName { player.toggle(fileName: f) }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .appFont(15, .semibold)
                        .foregroundStyle(AppColors.primaryText)
                        .frame(width: 42, height: 42)
                        .background(AppColors.voiceAccent.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "pausar" : "tocar gravação")

                VStack(alignment: .leading, spacing: 6) {
                    Text(title).appFont(16, .medium).foregroundStyle(AppColors.primaryText).lineLimit(1)
                    StaticWaveform(peaks: note.waveform, progress: progress).frame(height: 22)
                    HStack(spacing: 6) {
                        Text(note.createdAt, format: .relative(presentation: .named))
                        Text("· \(qnTimeString(note.audioDuration))")
                        if !note.voiceAnnotation.isEmpty {
                            Text("· \(note.voiceAnnotation)").lineLimit(1)
                        }
                    }
                    .appFont(12).foregroundStyle(AppColors.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(CategoryTint.wash(.voice), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.hairline, lineWidth: 0.5))
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("nota de voz, \(title), \(qnTimeString(note.audioDuration))")
    }
}
```

- [ ] **Step 2: Route voice notes in the feed**

In `NoteComponents.swift` where the feed builds a `NoteCard` per note (the `ForEach` over notes), branch:
```swift
if note.isVoice {
    VoiceCard(note: note) { onOpen(note) }   // reuse the existing open-detail closure
} else {
    NoteCard(note: note, /* existing args */ )
}
```
Use whatever the existing card's open/tap closure is named; match it exactly.

- [ ] **Step 3: Build + sim check**

Run: `xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' build`
Expected: `** BUILD SUCCEEDED **`. On sim: the voice card shows a real waveform; tapping play fills it left→right; tapping the card opens detail.

- [ ] **Step 4: Commit**

```bash
git add QuickNote/QuickNote/Sources/Features/Mind/VoiceCard.swift QuickNote/QuickNote/Sources/Features/Mind/NoteComponents.swift
git commit -m "feat(voice): voice card with real waveform + feed routing"
```

---

## Task 9: Voice hero in NoteDetailSheet (player + annotation + transcribe + review)

**Files:**
- Modify: `Sources/Features/Mind/NoteDetailSheet.swift` (add `voiceHero`, gate at ~245 like `movieHero`)

- [ ] **Step 1: Add player panel + review editor + voice hero**

In `NoteDetailSheet.swift` add, near `movieHero`:
```swift
@Environment(AudioPlayerService.self) private var audioPlayer
@State private var isTranscribing = false
@State private var showReview = false

private var voiceHero: some View {
    VStack(alignment: .leading, spacing: 16) {
        if let file = note.audioFileName {
            PlayerPanel(fileName: file, peaks: note.waveform,
                        duration: note.audioDuration, player: audioPlayer)
        }
        // drill pill
        Menu {
            Button("livre") { note.drill = nil }
            ForEach(RoteiroDrill.allCases) { d in Button(d.label) { note.drill = d.rawValue } }
        } label: {
            let label = note.drill.flatMap { RoteiroDrill(rawValue: $0)?.label } ?? "+ marcar exercício"
            Pill(text: label, isActive: note.drill != nil)
        }

        // annotation
        VStack(alignment: .leading, spacing: 8) {
            Text("anotações").appFont(14, .medium).foregroundStyle(AppColors.secondaryText)
            TextEditor(text: Binding(get: { note.voiceAnnotation }, set: { note.voiceAnnotation = $0 }))
                .appFont(16).frame(minHeight: 120).scrollContentBackground(.hidden).padding(10)
                .background(CategoryTint.wash(.voice), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }

        // transcribe (hidden once transcribed)
        if !note.isTranscribed && VoiceTranscriptionService.isAvailable {
            Button { Task { await transcribe() } } label: {
                HStack(spacing: 6) {
                    if isTranscribing { ProgressView().controlSize(.small) }
                    else { Image(systemName: "sparkles") }
                    Text(isTranscribing ? "transcrevendo…" : "transcrever")
                }
                .appFont(15, .medium).foregroundStyle(AppColors.voiceAccent)
            }
            .disabled(isTranscribing)
        } else if note.isTranscribed {
            Text(note.displayText ?? note.rawText).appFont(16).foregroundStyle(AppColors.primaryText)
        }

        // review disclosure
        DisclosureGroup(isExpanded: $showReview) {
            ReviewEditor(review: Binding(
                get: { note.voiceReview ?? VoiceReview() },
                set: { note.voiceReview = $0.isEmpty ? nil : $0 }))
                .padding(.top, 8)
        } label: {
            Text("revisão rápida").appFont(14, .medium).foregroundStyle(AppColors.secondaryText)
        }
        .tint(AppColors.secondaryText)
        .onAppear { showReview = !(note.voiceReview ?? VoiceReview()).isEmpty }
    }
}

private func transcribe() async {
    guard let file = note.audioFileName else { return }
    isTranscribing = true
    defer { isTranscribing = false }
    do {
        let text = try await VoiceTranscriptionService.transcribe(fileName: file)
        note.rawText = text
        let embedded = EmbeddingService.shared.embed(note.embeddingInput)
        note.embedding = embedded.vector
        note.langCode = embedded.language
        HapticEngine.classify()
    } catch {
        // surface via existing toast mechanism if available; else no-op, keep audio-only
    }
}
```
Add `PlayerPanel` and `ReviewEditor` to `CaptureRecordingSheet.swift` (shared voice subviews), adapted from the downloaded `VoiceComponents.swift` but using `StaticWaveform` for the scrubber and `AppColors`:
```swift
struct PlayerPanel: View {
    let fileName: String
    let peaks: [Float]
    let duration: TimeInterval
    let player: AudioPlayerService
    private var isThis: Bool { player.playingFileName == fileName }
    private var isPlaying: Bool { player.isPlaying && isThis }
    private var progress: Double { isThis ? player.progress : 0 }
    private var elapsed: TimeInterval { isThis ? player.currentTime : 0 }
    var body: some View {
        HStack(spacing: 14) {
            Button { player.toggle(fileName: fileName) } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .appFont(16, .semibold).foregroundStyle(AppColors.primaryText)
                    .frame(width: 46, height: 46)
                    .background(AppColors.voiceAccent.opacity(0.28), in: Circle())
            }.buttonStyle(.plain)
            VStack(spacing: 6) {
                GeometryReader { geo in
                    StaticWaveform(peaks: peaks, progress: progress)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                            if isThis { player.seek(toFraction: min(1, max(0, v.location.x / geo.size.width))) }
                        })
                }.frame(height: 26)
                HStack {
                    Text(qnTimeString(elapsed)).monospacedDigit(); Spacer()
                    Text(qnTimeString(duration)).monospacedDigit()
                }.appFont(12).foregroundStyle(AppColors.secondaryText)
            }
        }
        .padding(14)
        .background(CategoryTint.wash(.voice), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ReviewEditor: View {
    @Binding var review: VoiceReview
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\"tipo / né / então\"").appFont(15).foregroundStyle(AppColors.secondaryText)
                Spacer()
                Stepper(value: Binding(get: { review.fillerCount ?? 0 },
                                       set: { review.fillerCount = $0 }), in: 0...99) {
                    Text("\(review.fillerCount ?? 0)").monospacedDigit().foregroundStyle(AppColors.primaryText)
                }.labelsHidden()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("ritmo").appFont(15).foregroundStyle(AppColors.secondaryText)
                HStack(spacing: 8) {
                    ForEach(RecordingPace.allCases) { p in
                        DrillChip(label: p.label, selected: review.pace == p.rawValue) {
                            review.pace = (review.pace == p.rawValue) ? nil : p.rawValue
                        }
                    }
                }
            }
            quietField("1 coisa que melhorou", text: $review.improved)
            quietField("1 coisa pra focar", text: $review.focusNext)
        }
    }
    private func quietField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text, axis: .vertical).appFont(16).padding(12)
            .background(AppColors.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
```
(If `Pill`'s init differs from `Pill(text:isActive:)`, match the real signature in PolishKit.)

- [ ] **Step 2: Gate the hero in the detail body**

Near line 245 where `if note.hasMedia { movieHero … }`:
```swift
if note.isVoice {
    voiceHero.padding(.bottom, 18)
} else if note.hasMedia {
    movieHero.padding(.bottom, 18)
}
```
Ensure the normal text/title/tasks sections that don't apply to a pre-transcribed voice note are hidden when `note.isVoice && !note.isTranscribed` (no rawText to show).

- [ ] **Step 3: Build + sim check**

Run: `xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' build`
Expected: `** BUILD SUCCEEDED **`. On sim: open a voice note → play with scrubber, type an annotation (persists on reopen), tap transcribe → text appears, transcribe button disappears.

- [ ] **Step 4: Commit**

```bash
git add QuickNote/QuickNote/Sources/Features/Mind/NoteDetailSheet.swift QuickNote/QuickNote/Sources/Features/Mind/CaptureRecordingSheet.swift
git commit -m "feat(voice): detail voice hero with player, annotation, transcribe, review"
```

---

## Task 10: Lifecycle — delete cleanup + export marker

**Files:**
- Modify: wherever a `Note` is hard-deleted (search `modelContext.delete`) in `MindView.swift`/`NoteComponents.swift`
- Modify: `Sources/Services/ExportService.swift`

- [ ] **Step 1: Remove audio on delete**

At each note hard-delete site, before `modelContext.delete(note)`:
```swift
if note.isVoice, let f = note.audioFileName { RecordingsDirectory.remove(f) }
audioPlayer.stop()   // if a player is in scope; else stop in the view that owns it
```

- [ ] **Step 2: Export marker**

In `ExportService.markdown(from:)` where each note renders, for voice notes prefix the body:
```swift
if note.isVoice {
    let body = note.isTranscribed ? (note.displayText ?? note.rawText) : note.voiceAnnotation
    line += "🎙️ [voz \(Int(note.audioDuration))s] \(body)"
}
```
(Match the real loop variable names in ExportService.)

- [ ] **Step 3: Build + check**

Run: `xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' build`
Expected: `** BUILD SUCCEEDED **`. On sim: delete a voice note → confirm the file leaves Documents/Recordings/ (via a quick debug print or re-record count). Export → voice note shows the 🎙️ marker.

- [ ] **Step 4: Commit**

```bash
git add QuickNote/QuickNote/Sources/Features/Mind/MindView.swift QuickNote/QuickNote/Sources/Features/Mind/NoteComponents.swift QuickNote/QuickNote/Sources/Services/ExportService.swift
git commit -m "feat(voice): delete audio cleanup + markdown export marker"
```

---

## Task 11: Full runtime verification pass

**Files:** none (verification only)

- [ ] **Step 1: Clean build + launch on sim**

```bash
xcodebuild -scheme QuickNote -destination 'generic/platform=iOS Simulator' build
```
Boot the sim, install, launch. Confirm the migrated store opens (existing notes intact — voice fields defaulted).

- [ ] **Step 2: End-to-end walkthrough**

Verify in order: record → card in feed with real waveform → inline play → open detail → annotate → transcribe → note text + embedding set → recall finds it ("o que eu disse sobre …") → digest/echo can surface it → delete removes audio. Test mic-denied path (revoke permission). Test light + dark.

- [ ] **Step 3: Update memory**

Append a session note to the QuickNote project memory: voice as 5th NoteType shipped, files added, transcription = on-demand into corpus, sage tint, what was runtime-verified vs. pending.

- [ ] **Step 4: Final commit (if any verification fixes)**

```bash
git add -A
git commit -m "fix(voice): runtime verification pass"
```

---

## Self-review notes

- **Spec coverage:** model fields (T2), recorder+waveform (T3), player (T4), transcription (T5), tokens (T6), capture sheet+entry (T7), feed card+routing (T8), detail hero+annotation+transcribe+review (T9), delete cleanup+export (T10), reconcile two voices (existing dictation untouched; new record affordance is separate — T7), permissions (T0). All spec sections mapped.
- **Naming consistency:** `audioFileName`, `audioDuration`, `waveform`, `drill`, `voiceReview`, `voiceAnnotation`, `isVoice`, `isTranscribed`, `WaveformSampler.downsample(_:to:)`, `AudioRecorderService.stop(bars:)`, `AudioPlayerService.toggle(fileName:)`, `VoiceTranscriptionService.transcribe(fileName:)`, `StaticWaveform(peaks:progress:)`, `CaptureRecordingSheet(onSave:)`, `VoiceCard(note:onOpen:)` — used identically across tasks.
- **Known executor lookups (codebase-specific, match real symbols):** the feed `ForEach` open-detail closure name (T8), `Pill` init signature (T9), `.motion` helper signature (T7), the note hard-delete site(s) (T10), `ExportService.markdown` loop var (T10), `Color.dynamic`/`AppColors` token names (T6).
