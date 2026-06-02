# QuickNote Corpus Intelligence — Design

**Date:** 2026-06-01
**Status:** Approved for implementation (all four phases)

## Problem

The existing AI functions (rewrite/rephrase/enhance) operate on a single note in
isolation. They polish text the user already wrote, return nothing the user
couldn't produce themselves, and create no relationship. Net value ≈ cosmetic.

The user's corpus — hundreds of personal fragments — is the one asset a generic
LLM does not have. Every AI feature should exploit it.

## Promise

> The note app where what you write actually comes back when it matters.

The painkiller is **contextual resurfacing** (the note graveyard problem). The
delight wrapper is the capture ceremony already built.

## Design principles (interface)

1. **Never demand, always offer.** AI output never blocks, never modals, never
   requires a tap to dismiss. It appears at the edge and decays if ignored.
2. **Speak in the user's own words.** When the corpus returns something, it
   returns the user's past text — faded, verbatim — not a generic AI sentence.
   Claude is reserved for connective tissue only, rendered lighter than the
   user's words.
3. **Earn the foreground.** Quiet by default; only what the user reaches toward
   brightens. Reaching = the existing haptic grammar.
4. **Three states reuse existing effects:** dormant (invisible) → surfacing
   (faint, decaying, one whisper-haptic) → embraced (user reached, it brightens).

## Architecture

### Foundation: on-device semantic engine

- **`Note.embedding: [Double]`** — new persisted property (default `[]`).
  SwiftData lightweight migration (defaulted property) handles existing stores.
- **`EmbeddingService`** (`Sources/Services/`) — wraps
  `NLEmbedding.sentenceEmbedding(for: .english)`. `vector(for:) -> [Double]?`.
  Pure on-device, no network, no cost, works offline.
- **`SemanticIndex`** (`Sources/Services/`) — cosine similarity helpers and
  top-k retrieval over an in-memory `[Note]` corpus. No new persistence beyond
  the embedding field.
- **Backfill:** on app launch, embed any note whose `embedding` is empty
  (handles the existing corpus + the cold-start "grows as you write" honesty).

### Phase 1 — Engine

Note model field + EmbeddingService + SemanticIndex + launch backfill. Embed on
note insert in `submit()`. Invisible; no UI.

### Phase 2 — Echo at capture (the hero)

Rides existing `InkReveal` + `HapticEngine` + the `VStack(spacing: 4)` slot in
`MindView.noteList` (where the first-note ceremony already renders).

- After a note is inserted in `submit()`, if its type is `.note` or `.idea`,
  retrieve the single closest past note (not self, not archived) with cosine
  ≥ **0.62**. Below threshold → show nothing (silence is the default).
- On a hit: store `echoNote` + `echoForNoteID` on AppState. Render an
  **EchoThread** beneath the new card: a hairline vertical connector + one line
  of the matched note verbatim, ~50% opacity, italic-light (same treatment as
  the ceremony text).
- **`HapticEngine.echo()`** — single soft low-intensity tap, gentler than the
  `noteArrived` double.
- Pull the new card down → opens the matched note's `NoteDetailSheet`.
- Auto-decays after ~6s; thread retracts. Ignoring is free.
- No Claude, no network, instant, private.

### Phase 3 — Recall (second-mind query space)

- Entry: a small low-chrome mark-glyph affordance in `MindView.navRow`
  (visible, not a hidden gesture).
- `AppState.isRecalling: Bool` toggles a `RecallView` overlay in `MindView`'s
  ZStack, styled like `DigestDetailSheet` (`.ultraThinMaterial` + dark wash).
- User asks a question → embed query → `SemanticIndex` top-5 over corpus →
  matched notes float up as faded fragment cards.
- **`NoteProcessor.synthesize(query:snippets:) async -> String`** — single
  Claude call (`kClaudeModelID`), system prompt: answer using ONLY the provided
  notes, in the user's voice, one or two sentences, no outside info. Sends only
  the 5 snippets (privacy). Output rendered lighter than the user's fragments.
- Swipe down → collapses back to inbox. Pull-based, so 1–3s latency is fine.

### Phase 4 — Resurfacing (fold into digest)

- `DigestDetailSheet` gains one section: a single older reflective note
  (createdAt > 14 days ago, type `.note`/`.idea`) whose embedding is closest to
  the centroid of the last 7 days' captures. Framed "you wrote this. still
  true?" Tappable to open. No new notification — reuses the existing digest
  surface and the same embeddings.

## Explicitly cut

- Emotional/mood analysis ("you wrote about your sister, anxious") — too
  invasive, sentiment on short fragments too unreliable.
- Ambient hue drift — effort with no perceived value.
- Apple Notes import — deferred stretch; retroactive backfill covers existing
  notes for now.

## Risks mitigated

- **Cold start:** backfill + honest framing; echo works on any existing corpus.
- **False echoes:** high threshold + silence default; precision over recall.
- **Mundane notes:** type-gated — tasks/links get no soul-features.
- **Latency/cost on hero:** echo is local-only; Claude only in pull-based recall.
- **Privacy:** notes embedded/retrieved on-device; Claude sees only matched
  recall snippets.

## Constraints (from CLAUDE.md)

- SwiftUI only, iOS 17+, `@Observable`, no force-unwrap, explicit access
  modifiers, SwiftDoc on public APIs, views < 200 lines.
- Do not modify `.pbxproj`/`.storyboard`. New files auto-included via
  `PBXFileSystemSynchronizedRootGroup`.
- Model ID lives in `kClaudeModelID`; API key via Secrets/env.
