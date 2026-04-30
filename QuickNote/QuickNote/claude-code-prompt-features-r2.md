    # Claude Code Prompt — Feature Additions & UX Fixes

Implement everything below in order. Follow CLAUDE.md and DESIGN.md strictly
throughout. No new colors, no new typefaces, no new corner radius values
outside what is already defined.

---

## 0. UX FIXES (apply first — these are corrections to existing behaviour)

### 0.1 Navigation — Pill Toggle Symmetry
Remove the 2-dot scroll indicator between the Mind and Library tabs entirely.
Replace with a consistent pill button toggle: both "Mind" and "Library" must
use the same pill button style, symmetrical in both directions. Currently only
the Library button works as a pill — apply the exact same treatment to the
Mind tab so the user can navigate back from Library to Mind using the same
pattern. No asymmetry.

### 0.2 Mind Filters
Add a filter system to the Mind view. Items should be filterable by: alerts,
tags, subject, and status. Use the existing pill chip pattern from DESIGN.md —
horizontal scrolling row below the view title, monochrome, active chip is solid
black (#0A0A0B) with white text, inactive is rgba(10,10,11,0.06) with secondary
text. Filter state persists while the user is in the Mind view, resets on
navigation away.

### 0.3 Archive + Delete
Add both archive and delete actions to items in both the Mind view and the
Library view.
- Swipe left on any item to reveal two actions: "archive" (secondary style,
  rgba background) and "delete" (destructive, #EF4444)
- Archive moves the item to an archived state — hidden from the main view but
  recoverable. Add an "archived" filter chip to both views so the user can
  access archived items.
- Delete requires a confirmation step — a compact alert or action sheet:
  "Delete this note? This cannot be undone." with "Delete" (destructive) and
  "Cancel" options. Never delete on first tap.

### 0.4 Library URL Import
Add the ability to add an item to the Library by pasting a URL or link.
- Automatic detection: when the user pastes a URL into the capture bar anywhere
  in the app, detect it automatically (use a URL regex or iOS dataDetector) and
  route it to Library instead of Mind — no user decision required, no prompt
- Visual feedback: the capture bar label briefly changes to "saving to library..."
  in tertiary text for 1 second before processing
- Dedicated shortcut: in the Library view, add a "paste link" button — a pill
  chip with a link glyph, positioned in the filter chips row as the last item.
  Tapping it reads the clipboard and immediately processes whatever URL is there.
  If clipboard is empty or not a URL: show inline tertiary message "no link in
  clipboard" that fades after 2 seconds.

---

## 1. VOICE CAPTURE

Add voice input to the capture bar.

- A microphone glyph button sits on the left side of the capture bar, visible
  only when the text field is empty (mirror the send button logic on the right)
- Hold to record, release to transcribe — use iOS SpeechKit (Speech framework)
  for on-device transcription
- While recording: the capture bar border pulses gently using springGentle
  animation, mic icon fills black to indicate active state
- On release: transcribed text appears in the field exactly as if the user
  typed it — from that point the normal AI processing flow takes over unchanged
- If transcription fails: show a single-line error in tertiary text below the
  bar — "couldn't catch that, try again" — disappears after 2 seconds
- No separate voice memo UI. No waveform visualizer. The capture bar IS the
  voice interface.

---

## 2. SHARE EXTENSION

Create an iOS share extension so the user can send content to Quicknote from
any app.

- Extension target: share sheet, accepts text and URLs
- When triggered from Safari or any app: a compact sheet slides up showing a
  preview of the selected text or URL, with the capture bar pre-filled
- The user can add context in the capture bar before saving, or just tap "save"
  immediately
- URL detection: if the shared content is a URL, automatically route the note
  to Library on save instead of Mind — no user decision required
- Sheet design: follows the Note Detail sheet pattern from DESIGN.md —
  .ultraThinMaterial background, 16pt card radius, same typography
- Uses App Groups to write directly to the shared SwiftData store
- After save: sheet dismisses and returns the user to whatever app they came from

---

## 3. RELATED NOTES

On the Note Detail view, add a "see also" section at the bottom.

- After the summary line and before the delete option: a section labeled
  "see also" in 11pt Medium uppercase secondary
- Shows 2–3 semantically related notes as compact rows — category glyph,
  truncated note text, timestamp
- Relatedness is determined by a lightweight second Claude API call that takes
  the current note's rawText and tags and returns IDs of the 2–3 most related
  notes from the local store
- Only shown if related notes exist and similarity confidence is above threshold
- If no related notes: section is hidden entirely — no empty state for this one
- Tapping a related note opens its detail sheet (push onto the sheet stack)
- This must never feel like an algorithm. No "recommended" language. Just
  "see also" — quiet and editorial.

---

## 4. WEEKLY DIGEST CARD

A passive summary card that appears in the inbox on Sunday evenings.

- Card type: a special NoteType case — `.digest` — styled differently from
  regular note cards
- Digest card design: slightly taller than standard cards, no category badge,
  no timestamp — instead shows the week range (e.g. "Apr 21 – Apr 27")
- Content: "X thoughts captured · Y tasks completed · Z ideas saved"
  Each stat on its own line, 17pt SemiBold for the number, 13pt Light secondary
  for the label
- Generated locally — no API call needed, computed from SwiftData queries
- Appears at the top of the inbox Sunday after 6pm, disappears Monday at midnight
- Not a notification. Never pushes an alert. Purely passive — it's just there
  when you open the app.
- Tap to expand: shows a brief breakdown by category. Same sheet pattern.

---

## 5. AI ENHANCER (PRO FEATURE)

Add an optional AI refinement pass to any captured note. This is a PRO-gated
feature — implement the full UI and logic but wrap the actual API call in a
isPro guard that can be toggled for development.

### Trigger
- On the Note Detail view: a sparkle glyph button (✦) appears in the top-right
  corner of the raw note text area
- Button style: 28pt circle, rgba(10,10,11,0.06) background, ✦ glyph in
  secondary color — subtle, does not compete with the note text
- If user is not PRO: tapping shows a compact upgrade prompt sheet (design below)

### Enhancement Modes
Present four modes as pill chips in a horizontal row after tapping the sparkle:

  1. **Clarity** — rewrites messy input into clear, readable prose. Same intent,
     better words.
  2. **Expand** — develops a fragment into a structured note with context and
     angles. Best for Ideas.
  3. **Sharpen** — converts vague tasks into specific, actionable items with
     implicit deadlines surfaced.
  4. **Reframe** — rewrites anxious or emotional captures as calm, structured
     observations.

### Interaction flow
1. User taps ✦ on detail view
2. Mode selector appears below the note text as a pill chip row (animated in
   with springFluid)
3. User taps a mode chip
4. Chip goes active (black fill), sparkle button begins breathing pulse
5. API call fires with the rawText + selected mode as context
6. Original text fades out (opacity 0, springFluid 0.4s)
7. Enhanced text fades in at same position (opacity 1, springFluid 0.5s)
8. Two new buttons appear below: "keep" (primary black) and "revert" (secondary)
9. "keep" saves enhanced text as the note's displayText while preserving rawText
   in a separate field — the original is never destroyed
10. "revert" restores original text with same fade animation in reverse

### Claude API prompt structure per mode
```swift
// Clarity
"Rewrite the following note in clear, concise prose. Keep the exact same
meaning and intent. Do not add information. Do not use bullet points.
Return only the rewritten text, nothing else.\n\nNote: {rawText}"

// Expand
"The following is a brief idea or fragment. Expand it into a structured note
with 2-3 sentences of context and one clearly stated angle or direction.
Do not add speculation beyond what is implied. Return only the expanded
note.\n\nNote: {rawText}"

// Sharpen
"The following contains one or more tasks. Rewrite each task to be specific,
actionable, and time-aware where possible. Extract implied deadlines or
urgency. Return as a clean list, one task per line, no bullet characters.
Return only the sharpened tasks.\n\nNote: {rawText}"

// Reframe
"The following note may be anxious, vague, or emotionally charged. Rewrite
it as a calm, clear observation or structured list of concrete next steps.
Do not dismiss or minimize the emotion — just translate it into something
actionable and readable. Return only the reframed text.\n\nNote: {rawText}"
```

### PRO upgrade prompt sheet
Triggered when non-PRO user taps ✦:
- Compact bottom sheet, 280pt height
- ✦ glyph at 32pt centered, top
- "Quicknote Pro" in Bold 22pt
- "AI enhancement, unlimited captures, priority processing" in Light 13pt
  secondary, centered, 2 lines
- Two buttons: "try for free" (primary black, 7-day trial) and "maybe later"
  (tertiary text only, no chrome)
- No pricing shown in the UI — links to StoreKit sheet on CTA tap
- Sheet is dismissible by swipe down

---

## IMPLEMENTATION NOTES

### Note model additions required
- rawText: always preserved, immutable after creation
- displayText: String? — shown in UI, falls back to rawText when nil
- enhancementMode: String? — records last applied AI enhancer mode
- isArchived: Bool — default false, used by archive/delete system
- Add archived filter logic to both Mind and Library query predicates

### App state
- isPro: Bool in a UserDefaults-backed AppState singleton — replace with
  StoreKit receipt validation later

### Networking
- All new API calls go through the existing NoteProcessor service — add new
  methods, do not create parallel networking code

### Permissions (Info.plist)
- NSMicrophoneUsageDescription — required for voice capture
- NSSpeechRecognitionUsageDescription — required for SpeechKit transcription
- NSPasteboardUsageDescription — required for clipboard URL reading on iOS 16+

### URL detection
- Use NSDataDetector with .link type for robust URL detection in capture bar
  and clipboard reading — more reliable than regex

### Xcode manual steps (remind me after file creation)
- Share extension requires a new target — remind me to add it to the project
  navigator manually
- Any new Swift files created need to be dragged into the correct Xcode group
