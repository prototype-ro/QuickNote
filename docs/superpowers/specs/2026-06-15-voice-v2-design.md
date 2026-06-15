# Voice v2 — background recording, color stamps, scrub, swipe fix, Live Activity

**Date:** 2026-06-15
**Status:** Approved (design)
**Builds on:** `2026-06-15-voice-capture-type-design.md` (voice = 5th NoteType, already merged to main)

## Goal

Five increments on the shipped voice feature, in build order:
A. Fix the note-card swipe-to-delete/archive bug (#4).
B. Background recording — keep recording when the app is backgrounded/locked (#1).
C. Color stamps with optional labels, dropped during playback (#2) + scrub polish (#3).
D. Live Activity — lock screen + Dynamic Island recording display with a Stop control (#5).

## Locked decisions

| Topic | Decision |
|---|---|
| Stamp palette | 6 distinct hues: red, amber, green, teal, blue, violet (for at-a-glance recall) |
| Stamp content | color + optional short text label |
| Stamp timing | playback only (live-recording stamping is a future follow-up) |
| Live Activity | build now; user created the ActivityKit/Widget Extension target |
| Background cap | none — user stops manually; ends cleanly if iOS terminates the app |

## Manual Xcode prerequisites (user — done / to confirm)

- App target Info: `NSSupportsLiveActivities = YES`.
- App target Signing & Capabilities: Background Modes → **Audio**.
- App target Info (from voice v1): `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` (strings).
- New target **QuickNoteLiveActivity** (Widget Extension, "Include Live Activity"), bundle `com.prototype.QuickNote.QuickNoteLiveActivity`, member of App Group `group.com.prototype.QuickNote`.

## Architecture spine: RecordingCoordinator

Today the active recording is the capture sheet's local `@State AudioRecorderService`. That can't survive the sheet/app lifecycle and isn't reachable by a Live Activity or a lock-screen Stop button. Introduce:

`Sources/Services/RecordingCoordinator.swift` — an `@Observable` **singleton** (`static let shared`) that owns the one active `AudioRecorderService`, exposes `state`, `elapsed`, `level`, `selectedDrill`, and drives the Live Activity lifecycle. Also injected into the environment for views.

```swift
@Observable
final class RecordingCoordinator {
    static let shared = RecordingCoordinator()
    private let recorder = AudioRecorderService()
    var state: AudioRecorderService.State { recorder.state }
    var elapsed: TimeInterval { recorder.elapsed }
    var level: CGFloat { recorder.level }
    var selectedDrill: RoteiroDrill?
    /// Set by the app so the coordinator (or a lock-screen intent) can persist a finished recording.
    var onFinish: ((_ fileName: String, _ duration: TimeInterval, _ waveform: [Float], _ drill: RoteiroDrill?) -> Void)?

    func start() async        // starts recorder + begins Live Activity
    func stop()               // stops recorder, calls onFinish, ends Live Activity
    func cancel()             // discards recorder + ends Live Activity
}
```

The capture sheet becomes a thin view over `RecordingCoordinator.shared` (no local recorder). `MindView` sets `coordinator.onFinish = insertVoiceNote(...)` in `.onAppear`, so a recording started in the sheet is inserted into the feed even if the sheet/app was backgrounded, and the lock-screen Stop path inserts it too.

This is the minimal change that makes B and D possible; it also keeps the recorder out of transient view state (cleaner than v1).

## A — Swipe-to-delete/archive bug (#4)

**Symptom:** swiping a note card snaps back instantly; archive/delete never stay revealed or accept taps.

**Approach:** systematic-debugging, not a guess-patch. Form the hypothesis, instrument, confirm, then fix. Leading suspects to verify in order:
1. `MindView` root `.simultaneousGesture(TapGesture().onEnded { resignFirstResponder })` fires on the swipe's end and the card's reset animation pulls `dragOffset` back to 0.
2. The whole `NoteCard` is a `Button`; the revealed archive/delete buttons sit *under* it in z-order / hit-testing, so taps hit the card.
3. `cardDragGesture`'s `onEnded` resolution thresholds resolve back to 0 for normal-speed swipes.

**Fix (shape, finalized after diagnosis):** make the revealed action buttons hit-testable above the card content, and stop the global tap gesture / card tap from collapsing an open swipe (e.g. gate the resign-first-responder tap when any card has a non-zero `dragOffset`, or convert to native `.swipeActions` if the card can live in a `List` — but the feed is a `LazyVStack`, so keep the custom gesture and fix hit-testing + reset). The exact fix is whatever the diagnosis proves; the test is: swipe reveals actions, they stay, and tapping archive/delete fires the right closure.

## B — Background recording (#1)

- Audio session already `.playAndRecord`; with Background Modes → Audio, `AVAudioRecorder` keeps running while backgrounded/locked because the process stays alive.
- Move ownership to `RecordingCoordinator` so the recording isn't bound to the presented sheet. The user can leave the app; on return the sheet (if still up) reflects the same coordinator; if the sheet was dismissed, recording continues and is stopped via the Live Activity or by reopening capture.
- On `stop()`/`cancel()`, deactivate the session with `.notifyOthersOnDeactivation` (already in AudioRecorderService).
- No artificial duration cap.

## C — Color stamps (#2) + scrub polish (#3)

**Model:** `Note.voiceMarks: [VoiceMark] = []` (migration-safe array).
```swift
struct VoiceMark: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var time: Double        // seconds into the recording
    var colorIndex: Int     // 0...5 into StampPalette
    var label: String = ""
}
```
**Palette:** `StampPalette.colors: [Color]` in Theme — 6 fixed hues (red `EF4444`, amber `E8B26A`, green `5FB87A`, teal `4FB3B3`, blue `7AA7FF`, violet `A89BD8`). Index-based so persistence is stable.

**Detail (playback) UI:**
- A `+ marca` button near the player drops a `VoiceMark` at `audioPlayer.currentTime` (default colorIndex 0). Haptic.
- `StaticWaveform` / `PlayerPanel` render the marks as colored vertical ticks at `time/duration` x-position.
- A **stamps list** below the player: each row = timestamp · color swatch · inline-editable label. Tap the swatch → a 6-color picker row; tap the row/tick → `audioPlayer.seek` to that time. Swipe/delete a stamp to remove it.
- Marks persist on the `Note` (reference type; SwiftData autosaves).

**Scrub polish (#3):** the existing `PlayerPanel` waveform drag → `seek(toFraction:)` already works. Enlarge the hit area (taller transparent overlay), add tap-to-seek, and clamp/smooth. The feed card stays static (scrub is a detail affordance).

## D — Live Activity (#5)

**New target QuickNoteLiveActivity** (already created). Shared types compiled into BOTH the app and the extension target.

- `RecordingActivityAttributes: ActivityAttributes` with `ContentState { elapsed: TimeInterval; levels: [Float] }`. Static attribute: a title/drill label.
- `RecordingCoordinator.start()` calls `Activity.request(...)`; a timer updates the activity (~1s cadence — iOS throttles, so cadence is best-effort) with elapsed + the last N levels for a waveform motif; `stop()`/`cancel()` calls `activity.end(...)`.
- **Views (in the extension):** lock-screen view (app mark + "gravando" + elapsed + waveform motif + Stop button) and Dynamic Island (compact: red dot + elapsed; expanded: + waveform + Stop).
- **Stop from lock screen:** a `LiveActivityIntent` (`StopRecordingIntent`) whose `perform()` calls `RecordingCoordinator.shared.stop()`. The intent type must be available to the app process; the coordinator's `onFinish` (set by the app) persists the note. (If the app is suspended when Stop is tapped, iOS wakes it to run the intent.)
- Waveform on the lock screen is an animated motif from periodic `levels`, NOT a real-time meter (documented limitation).

## Data flow (recording → note, all paths)

```
capture sheet  ─tap record→ RecordingCoordinator.start() ─→ AudioRecorderService + Live Activity
   app backgrounded/locked: recording continues (Background Modes: Audio)
stop via sheet button OR lock-screen StopRecordingIntent
   → RecordingCoordinator.stop() → recorder.stop()=(file,dur,waveform)
   → onFinish(file,dur,waveform,drill)  [set by MindView] → Note(type:.voice) inserted
   → Live Activity ends
```

## Error handling

- Mic denied → coordinator surfaces `.denied`; sheet shows denied state; no Live Activity started.
- Background recording interrupted (call, route change) → `AVAudioSession` interruption handler pauses; on resume, continue or stop-and-save the partial recording (save partial, never lose audio).
- Live Activity request fails (Activities disabled by user, or budget) → recording proceeds without the activity; no crash.
- Stop intent fires while app terminated → iOS relaunches to run it; if the recorder state is gone, end the stale activity gracefully.
- Stamp at time beyond duration (race) → clamp to `[0, duration]`.

## Testing

- `VoiceMark` Codable round-trip; clamp logic; mark→x-position mapping (pure func) given duration.
- `Note` migration with `voiceMarks` defaulted.
- RecordingCoordinator state transitions (idle→recording→idle) with a mock recorder.
- Swipe fix: manual on-device (gesture) + a note on the reproduction.
- Live Activity: manual on-device (simulator support for Live Activities is limited); verify start/update/stop and the Stop intent.
- Per-task gate stays BUILD SUCCEEDED + sim/device runtime (no test target unless created).

## Build order & isolation

A (swipe fix, standalone) → B (RecordingCoordinator + background) → C (stamps + scrub) → D (Live Activity, depends on B). Each lands as its own commit set and builds independently.

## Non-goals

- Live stamping during recording (future).
- True real-time waveform on the lock screen (iOS throttling).
- Trimming/editing audio.
- Push-updated Live Activities (local updates only).
