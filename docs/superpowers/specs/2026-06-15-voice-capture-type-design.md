# Voice capture as a first-class note type

**Date:** 2026-06-15
**Status:** Approved (design)
**Branch target:** main

## Goal

Add **voice** as a fifth first-class capture type, native to the existing unified
`Note` feed — not a separate recorder app-within-the-app. A voice capture is
*audio + annotations about the audio*. It lives in the same grammar as
note/task/idea/link: one more color (sage) in the family.

The driving use case is a **speech-practice diary** (the roteiro): each `[REC]`
drill becomes a voice note, and the "annotations about the recording" are the
review loop (count the *tipo/né*, mark the pace, note *1 melhorou / 1 focar*).
You train your speaking inside your own product — dogfooding.

## Decisions (locked)

| Decision | Choice |
|---|---|
| Storage | Extend the existing SwiftData `Note` model with a `.voice` type + optional fields. Voice notes flow natively into the mind feed. |
| Transcription | **Optional, on demand.** Record audio first; a `✦ transcrever` button in detail runs on-device speech recognition, fills the note text, embeds it → joins the corpus (echo/recall/digest). |
| Capture entry | **Dedicated capture sheet** (timer + live level + drill chips), reached from a record affordance on the capture bar. |
| Waveform | **Real samples** — captured live from the recorder's metering, downsampled and stored on the note. |
| Annotations | **New field** `voiceAnnotation` — keep `summary` reserved for AI output. |

## Non-goals (YAGNI)

- No background recording / live-activity capture.
- No cloud transcription — on-device `SFSpeechRecognizer` only.
- No editing/trimming of audio. Record, keep, annotate, delete.
- No automatic transcription on save (user-triggered only — saves battery, avoids
  surprise corpus pollution from throwaway recordings).

## Reconciling the two "voices"

The app already has `VoiceCaptureManager` (SFSpeechRecognizer) wired into the
capture bar: it dictates speech → text and **discards the audio**. That stays as
the fast text-dictation path. The new feature is audio-first: it **keeps** the
recording, lets you annotate it, and only transcribes on demand. Two distinct
affordances, clearly labeled. The record affordance must not collide with the
quiet-hours long-press on the MarkGlyph.

## Data model

All additions are optional / inline-defaulted → SwiftData lightweight migration
is safe (same rule that bit the `embedding` field: stored property defaults, not
just init defaults).

```swift
// NoteType.swift
case voice          // iconName: "waveform"

// Note.swift — new stored properties
public var audioFileName: String? = nil   // relative name in Documents/Recordings/
public var audioDuration: Double = 0      // seconds
public var waveform: [Float] = []         // ~48 normalized peaks (0...1), real samples
public var drill: String? = nil           // RoteiroDrill rawValue, optional
public var voiceReview: VoiceReview? = nil // Codable, like MediaInfo
public var voiceAnnotation: String = ""   // freeform "anotações sobre a gravação"

// Computed
public var isVoice: Bool { type == .voice }
public var isTranscribed: Bool { isVoice && !rawText.isEmpty }
```

`VoiceReview` is a `Codable, Equatable` struct (one attribute on `Note`, mirroring
`MediaInfo`):

```swift
public struct VoiceReview: Codable, Equatable {
    public var fillerCount: Int?       // "tipo / né / então"
    public var pace: String?           // "lento" | "bom" | "rapido"
    public var improved: String        // 1 coisa que melhorou
    public var focusNext: String       // 1 coisa pra focar
}
```

`RoteiroDrill` stays an enum (UI-side), persisted as its `rawValue` string in
`Note.drill` so the model has no UI dependency and migration stays trivial.

When transcribed, `rawText`/`displayText` hold the transcript and embedding +
`langCode` are computed via the existing `EmbeddingService` — voice then behaves
like any other note for echo/recall/digest.

## Components

### Services
- **`AudioRecorderService`** (`Sources/Services/`) — adapted from the downloaded
  `AudioEngine.swift`. Records mono AAC `.m4a` into `Documents/Recordings/`,
  exposes live `level`, `elapsed`, `state`. **Addition:** collect the metered
  levels into a buffer during recording; on `stop()`, downsample to ~48 peaks and
  return them alongside `(fileName, duration, waveform)`.
- **`AudioPlayerService`** (`Sources/Services/`) — from `AudioEngine.swift`. Single
  active player, publishes `isPlaying`, `progress`, `currentTime`, `playingFileName`.
  Injected via `.environment` so card + detail share one player (only one plays at
  a time).
- **`RecordingsDirectory`** — Documents/Recordings/ helper.
- **Transcription** — reuse `SFSpeechRecognizer` (a `transcribe(fileURL:) async`
  path; the existing `VoiceCaptureManager` is live-buffer only, so add a
  file-based recognition request `SFSpeechURLRecognitionRequest`). On success:
  set `rawText`, then run the existing embed-on-save logic.

### Models
- `NoteType.voice`, new `Note` fields, `VoiceReview`, `RoteiroDrill`.

### Views (all in `Sources/Features/Mind/`, following existing file split)
- **`VoiceCard`** (in `NoteComponents.swift` or a sibling) — the feed row:
  sage play circle, title/drill, real-waveform bar (played portion fills sage),
  duration, relative time, 1-line annotation peek. Tap play = inline playback via
  the shared player; tap card = open detail. Uses `CategoryTint.wash(.voice)`,
  `PressStyle`, `appFont`, VoiceOver labels.
- **`CaptureRecordingSheet`** — drill chips (livre + roteiro), big timer, live
  `LevelBar`, record button morphing ○→□. On stop: builds `Note(type: .voice, …)`
  with audio fields + waveform, inserts into `modelContext` → feed. Detent ~380.
- **Voice hero in `NoteDetailSheet`** — when `note.isVoice`, render a sage
  `PlayerPanel` (play/pause + real-waveform scrubber + times) at top, mirroring the
  movie hero pattern. Below: drill `Pill` (`+ marcar exercício`), `anotações`
  editor bound to `voiceAnnotation`, `✦ transcrever` button (hidden once
  transcribed), and a collapsed `revisão rápida` disclosure (filler stepper, ritmo
  pills, melhorou/focar).

### Design tokens
- Add `.voice` to `CategoryTint.wash` → sage at the shared 0.07 opacity. Map the
  downloaded `voiceTint` / `voiceTintSoft` onto the real adaptive token system
  (light/dark via `AppColors.dynamic`), not hardcoded `Color(red:…)`.

## Capture flow

1. Tap record affordance on the capture bar → `CaptureRecordingSheet`.
2. (Optional) pick a drill chip.
3. Record → live timer + level bars; metered levels buffered.
4. Stop → downsample buffer to waveform → `Note(type:.voice, audioFileName, audioDuration, waveform, drill)` inserted → sheet dismisses.
5. Card materializes in mind with ink-reveal + arrival haptic, sage badge-classify pop.

## Detail / transcription flow

1. Open voice note → PlayerPanel plays the `.m4a` (waveform fills with progress).
2. Annotate freely (`voiceAnnotation`), optionally fill `revisão rápida`.
3. `✦ transcrever` → `SFSpeechRecognizer` over the file → `rawText` set →
   `EmbeddingService.embed` → `embedding` + `langCode` saved. Button hides;
   note now appears in echo/recall/digest. "o que eu disse sobre X" surfaces it.

## Persistence & lifecycle

- Metadata: SwiftData `Note` (no separate JSON store — the downloaded
  `VoiceNoteStore` is dropped).
- Audio bytes: files in `Documents/Recordings/`. **On note delete**, remove the
  associated `.m4a`. Archive keeps the file.
- Export (`ExportService`) — voice notes export as their annotation/transcript text
  with a `[voice 1:42]` marker; audio binary is not included in Markdown export.

## Error handling

- Mic permission denied → sheet shows the denied state, record disabled, link to Settings.
- Recorder start failure → return to idle, no note created.
- Missing audio file at play time (e.g. deleted externally) → player no-ops, card shows a muted state.
- Transcription failure / no speech detected → toast "não consegui transcrever", note stays audio-only, retry allowed.
- `SFSpeechRecognizer` unavailable for locale → fall back to default locale; if still nil, hide the transcribe button.

## Permissions

- `NSMicrophoneUsageDescription` — required for recording (new copy needed).
- `NSSpeechRecognitionUsageDescription` — already needed by existing dictation; reused for file transcription.
- Both added to Info.plist (manual Xcode step — flagged in the plan).

## Testing

- `AudioRecorderService` downsampling: a known level buffer → expected peak count/values.
- `Note` migration: open a pre-voice store, confirm new fields default cleanly.
- `VoiceReview` Codable round-trip.
- `isTranscribed` / `isVoice` logic.
- Transcription path mocked (protocol around the recognizer) → sets text + triggers embed.
- Snapshot: VoiceCard (sage), CaptureRecordingSheet, voice hero in detail (light + dark).

## Open follow-ups (not in this spec)

- Drill-filtered "practice" view over time (trend of filler count / pace).
- Auto-transcribe toggle in Settings for power users.
- Reminder to review a recording N days later (BackgroundTasks).
