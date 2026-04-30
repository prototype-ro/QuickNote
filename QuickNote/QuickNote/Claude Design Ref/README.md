# Handoff: QuickNote — Cold-Premium Note Capture

## Overview

QuickNote is a private, mobile-first note-capture app built around a single brief: **"a quieter place than your own messages."** The user opens the app, captures a thought (text, task, idea, or URL), and an AI-style classifier sorts it. Thoughts live in **Mind**; URLs route automatically to a separate **Library** shelf so reference material never pollutes the active workspace.

The product positioning is **cold-premium** — restraint as luxury. Monochrome, frosted-glass surfaces, Helvetica Neue 800/300 contrast, one allowed accent color per session.

This handoff covers a complete iOS-style mobile prototype: splash → Mind inbox → AI processing → note detail → Library shelf, plus empty states and a lock-screen widget.

## About the Design Files

The files in this bundle are **design references created in HTML/JSX** — prototypes showing intended look and behavior, **not production code to copy directly.**

Your task is to **recreate these designs in the target codebase's existing environment** (SwiftUI, React Native, Flutter, etc.) using its established patterns, design system, and component library. If no environment exists yet, choose the most appropriate framework for a mobile-first app — SwiftUI for native iOS is the strongest match given the iOS-style status bar, page dots, and gesture model. React Native is a reasonable cross-platform choice. The HTML/JSX is illustrative; ignore the React/web specifics and focus on the visual and behavioral intent.

## Fidelity

**High-fidelity (hifi).** Pixel-perfect mockups with final colors, typography, spacing, and interaction timings. Recreate the UI pixel-perfectly, lifting the exact tokens listed below.

## Files in This Bundle

| File | Purpose |
|---|---|
| `QuickNote.html` | Entry point. Sets up the design canvas (presentational, you can ignore) and the Tweaks panel. |
| `app.jsx` | All Mind-side components: `Phone`, `Wallpaper`, `StatusBar`, `Mark`, `HeroMark`, `CatIcon`, `Glass`, `GlossButton`, `FilterChips`, `NoteCard`, `Badge`, `CaptureBar`, `DetailSheet`, `SplashScreen`, `InboxScreen`, `ProcessingScreen`, `DetailScreen`, `LockScreen`, `EmptyScreen`, and the live `Prototype` state machine. |
| `library.jsx` | Library-side components: `LibraryScreen`, `LibraryGrid`, `LinkCard`, `MockThumb`, `PlatformPill`, `LibraryToast`. |
| `library-detail.jsx` | (Not present — Library detail view is a future deliverable.) |
| `design-canvas.jsx`, `tweaks-panel.jsx`, `ios-frame.jsx` | Tooling for the design preview environment — **do not port.** |

---

## Screens / Views

### 1. Splash / Onboarding

- **Purpose:** First-launch entry point. Sets brand voice in one breath.
- **Layout:** Phone frame (390×844). Vertically centered glyph + wordmark + tagline. Bottom-anchored CTA.
- **Components:**
  - **HeroMark** at center (size 72, halo `#7AA7FF`, breathing animation `qn-breathe 2.6s ease-in-out infinite`)
  - **Wordmark** "quicknote" — Helvetica Neue 800, 30px, letter-spacing −0.7px, color `#0A0A0B`
  - **Tagline** "a quieter place / than your own messages." — Helvetica Neue 300, 15px, color `#6B7280`, max-width 260px, line-height 1.45, centered
  - **GlossButton** "get started" — full-width, gradient `linear-gradient(180deg, #1a1a1d, #000)`, white text, height 52px, border-radius 14px, inset highlight `inset 0 1px 0 rgba(255,255,255,0.22), inset 0 -1px 0 rgba(0,0,0,0.5)`, shadow `0 4px 10px rgba(0,0,0,0.18)`
  - **Footer text** "private by default · no account required" — 12px, color `#9CA3AF`, font-weight 300, centered

### 2. Mind (Inbox) — the primary surface

- **Purpose:** A reverse-chronological feed of captured thoughts (tasks, ideas, notes). Where the user lives.
- **Layout:** Phone frame. Top-down: status bar (44) → nav row (44) → title block (76) → filter chips (44) → scrollable note list (top: 230, bottom: 0). Floating capture bar pinned 36px from bottom with page dots 102px from bottom.
- **Components:**
  - **Nav row** (height 44, padding 0 20):
    - Left: `Mark` glyph (size 22, stroke 1.4) — rounded square with interior diagonal
    - Right: **Library button** — pill shape, height 32, padding 0 12 0 10, background `rgba(10,10,11,0.06)`, border-radius 999, inset border `inset 0 0 0 0.5px rgba(10,10,11,0.06)`. Contains: stack icon (3 stacked rectangles, 14×14), label "library" (13px, weight 400), count badge (min-width 18, height 18, accent-color background, weight 600, tabular numerals, font-size 10.5px)
  - **Title block** (padding 4 20 18):
    - Greeting "good morning, alex." — 12px, weight 300, color `#9CA3AF`, letter-spacing −0.05
    - Title "mind" — Helvetica Neue 800, 34px, letter-spacing −1px, line-height 1
    - Inline meta "· N thoughts" — 12px, weight 300, color `#9CA3AF`
  - **FilterChips row** (padding 6 20 10, frosted backdrop):
    - Background: `linear-gradient(180deg, rgba(240,242,244,0.92) 0%, rgba(240,242,244,0.78) 70%, rgba(240,242,244,0) 100%)`
    - `backdrop-filter: blur(12px) saturate(160%)`
    - z-index: 2
    - Chips: "all", "tasks", "ideas", "notes" — height 28, padding 0 10, border-radius 999. Active chip uses gradient `linear-gradient(180deg, #1a1a1d, #000)` with white text. Inactive uses `rgba(10,10,11,0.06)` with `#6B7280` text. Helvetica Neue 11px weight 500, letter-spacing 0.3, uppercase.
  - **Note list** (absolute, top 230, bottom 0, overflow-y auto):
    - Mask-image fade: `linear-gradient(to bottom, transparent 0, #000 18px, #000 calc(100% - 120px), transparent calc(100% - 24px))` — soft fade at top and bottom
    - Cards: gap 10px, padding 14 20 140
    - Card-in animation: `qn-card-in 320ms cubic-bezier(.2,.7,.2,1) both`, staggered 40ms per card
  - **Page dots** (absolute, bottom 102, centered): two 6×6 circles with 6px gap. Active dot: `#0A0A0B` opacity 0.85. Inactive: `#0A0A0B` opacity 0.18.
  - **CaptureBar** (absolute, left 16, right 16, bottom 36) — frosted glass pill (see Components below)

### 3. AI Processing — "thinking…"

- **Purpose:** Brief intermediate state after a thought is submitted. Reassures the user that classification is happening.
- **Layout:** Full-screen frosted overlay over Mind.
- **Components:**
  - Backdrop: `rgba(240,242,244,0.55)` with `backdrop-filter: blur(14px)`
  - HeroMark size 64, breathing, halo accent color
  - Caption "thinking…" — 15px weight 300, color `#6B7280`, italic
  - Duration: 1400ms, then resolves to inbox

### 4. Note Detail

- **Purpose:** Full view of a single captured thought. Shows extracted action items, tags, and AI-generated summary.
- **Layout:** Bottom sheet, 92% screen height, slides up from bottom (`qn-sheet-in 360ms`).
- **Components:**
  - **Drag handle** — 36×4 pill, `rgba(10,10,11,0.18)`, 12px from top, centered
  - **Header row:** Badge for kind + meta "captured · now"
  - **Subtitle** "from a tuesday afternoon." — italic, 13px, color `#6B7280`
  - **Title** — full thought text, Helvetica Neue 700, 22px, letter-spacing −0.5
  - **ACTION ITEMS section** (only on tasks):
    - Section header "ACTION ITEMS" — 10.5px weight 500 letter-spacing 0.8 uppercase
    - Checkbox rows: 18×18 circle border, filled when checked. Strikethrough text on completion.
  - **TAGS row:** Inline pills — same Badge component, comma-separated
  - **SUMMARY section:** "three concrete steps to take this week. circulate by friday: venue, invite, agenda." — 14px weight 300 italic
  - **Bottom action bar:** "delete note" link, color `#C8362F`

### 5. Library — the quieter shelf

- **Purpose:** Saved URLs (videos, articles, social, audio). Image-first, browse-mode, separate from Mind.
- **Layout:** Phone frame. Status bar → back nav (44) → title block (~84) → host filter row (~36) → 2-column masonry grid (top 198, scrollable, mask fade).
- **Slide-in:** `qn-slide-in-right 360ms cubic-bezier(.2,.7,.2,1)` when entering from Mind.
- **Components:**
  - **Back nav:** "← mind" — 13px weight 300, color `#6B7280`
  - **Title:** "library · N saved" — same scale as Mind title
  - **Host filter chips:** "all", "video", "reading", "audio", "social" — same chip style as FilterChips
  - **LibraryGrid:** 2 columns, gap 10, padding 0 16. Each LinkCard:
    - **MockThumb:** Per-platform gradient block with aspect ratio (varies 0.7–1.6 for masonry feel). Border-radius 14, inset shadow `inset 0 1px 0 rgba(255,255,255,0.06), 0 0 0 0.5px rgba(10,10,11,0.08)`. In production: og:image fetched at save time.
      - YouTube palette: `#1a1a1d → #2a2a30 → #16161a` + centered play button (44×44 frosted disc)
      - TikTok palette: `#0a0a0b → #1a1a22 → #0a0a14` + cyan/red glow overlay
      - Instagram palette: `#3a2a3a → #5a3a5a → #2a1a2a`
      - Article palette: `#e8e6e1 → #d8d4cc → #cdc8be` + faint serif "A" mark
      - Spotify palette: `#0e1a14 → #1a2a20 → #0a140e` + waveform bars at 18% opacity
      - Bare/default: `#dcdfe3 → #cdd2d8 → #bec4cc`
    - **PlatformPill:** Top-left, 18px tall, padding 0 7, platform-colored background, white uppercase 9px label
    - **Duration badge:** Bottom-right, 16px tall, `rgba(10,10,11,0.78)` background, white 9.5px tabular text
    - **Title:** 12px weight 500, line-height 1.3, max 2 lines (`-webkit-line-clamp: 2`), `text-wrap: pretty`
    - **Meta:** Author or host · readTime — 10.5px weight 300, color `#9CA3AF`
  - **Page dots:** Same as Mind, second dot active

### 6. Lock Screen Widget

- **Purpose:** Quick-capture from outside the app. iOS lock screen widget.
- **Layout:** iOS lock screen mock with widget tile.
- **Components:** Time + date stack, then a single rounded-rect widget with `Mark` glyph, "QuickNote", and a single-line "tap to capture" hint.

### 7. Empty States

Three variants, all using the centered `HeroMark` + heading + subhead + ghost capture bar pattern.

| Variant | Hero | Heading | Sub |
|---|---|---|---|
| `inbox` (zero notes) | size 68 with halo | "your brain's offsite." | "fill it back up." |
| `filter` (filter has no matches) | size 56 with halo | "no tasks yet." | "they'll surface here once you mention them." |
| `first` (first launch) | size 68 with halo, `breathe` | "nothing here yet." | "capture your first thought." (capture bar pulses with `qn-pulse 2s`) |

---

## Interactions & Behavior

### Capture flow

1. User types in capture bar at bottom of Mind.
2. Send button fades in (`opacity 0→1`, `scale 0.6→1`, `220ms cubic-bezier(.2,.7,.2,1)`) when input is non-empty.
3. On Enter or send tap:
   - **If text matches URL regex** (`/(https?:\/\/|www\.|\.com|\.org|\.io|\.net|youtu\.be|tiktok|instagram)/i`):
     - Capture bar clears
     - **LibraryToast** appears: "✓ saved to library [peek →]" — 240ms fade, 2400ms visible. Tapping "peek" navigates to Library.
     - **No state change in Mind** — URL never appears as a Mind note.
   - **Else:**
     - Capture bar clears, processing overlay appears for 1400ms
     - Classifier (heuristic):
       - `task` if text starts with imperative verb (`call|email|book|finish|send|finalize|plan|buy|fix|ship|prep`)
       - `idea` if contains `?`, "what if", "maybe", "idea"
       - `note` otherwise
     - New card prepended to Mind list with animation

### Mind ↔ Library navigation

Three independent affordances — **all three should work**:

1. **Library button (top-right of Mind):** Tap to navigate.
2. **Page dots (above capture bar):** Visual indicator only. Two dots, first active on Mind, second active on Library.
3. **Horizontal swipe:**
   - From Mind: swipe left starting in the right 28px gutter → Library slides in from right
   - From Library: swipe right starting in the left 28px gutter → Mind slides back in
   - Edge-only to avoid conflicts with input field, chip row, and per-card swipe-to-delete
   - Threshold: 50px horizontal travel, ≤40px vertical

### Per-note interactions

- **Tap card** → opens DetailSheet (sheet slides up 360ms, backdrop dims to `rgba(10,10,11,0.18)`)
- **Long-press / right-click card** → reveals "delete" affordance underneath via 90px translateX (280ms cubic-bezier(.2,.7,.2,1))
- **Tap action item checkbox** in detail → toggles strikethrough

### Detail sheet

- Drag-down to dismiss (production)
- Tap backdrop to dismiss
- Esc key to dismiss

### Animations (durations & easing)

| Animation | Duration | Easing | Properties |
|---|---|---|---|
| `qn-card-in` | 320ms | `cubic-bezier(.2,.7,.2,1)` | opacity 0→1, translateY 6→0 |
| `qn-fade-in` | 240ms | ease | opacity 0→1 |
| `qn-breathe` (HeroMark) | 2600ms | ease-in-out infinite | scale 1↔1.06, opacity 0.95↔1 |
| `qn-sheet-in` (DetailSheet) | 360ms | cubic-bezier | translateY 100%→0 |
| `qn-pulse` (capture bar in first-launch state) | 2000ms | ease-in-out infinite | box-shadow ring 0→6px |
| `qn-slide-in-right` (Library entry) | 360ms | `cubic-bezier(.2,.7,.2,1)` | translateX 100%→0 |
| Send button reveal | 220ms | `cubic-bezier(.2,.7,.2,1)` | opacity + scale |
| Card swipe-reveal | 280ms | `cubic-bezier(.2,.7,.2,1)` | translateX |

---

## State Management

### Top-level state (Mind)

```
stage: 'splash' | 'inbox' | 'processing' | 'detail' | 'library'
filter: 'all' | 'tasks' | 'ideas' | 'notes'
notes: Note[]   // captured thoughts (no URLs)
links: Link[]   // captured URLs (Library)
capture: string // text input value
active: Note | null   // currently-open note in detail sheet
swipedId: number | null // currently swipe-revealed card id
toastVisible: boolean   // "saved to library" toast
```

### Note shape

```
{
  id: number,
  kind: 'task' | 'idea' | 'note',
  time: string,        // relative time, e.g. "now", "12m", "yesterday"
  text: string,        // the captured thought
  sub: string,         // subtitle, e.g. "3 action items extracted"
  // Detail-only:
  actionItems?: { text: string, done: boolean }[],
  tags?: string[],
  summary?: string,
}
```

### Link shape

```
{
  id: string,
  kind: 'youtube' | 'tiktok' | 'instagram' | 'spotify' | 'article' | 'bare',
  host: string,        // e.g. "youtube.com"
  author?: string,     // e.g. "@cleartype"
  title: string,
  duration?: string,   // for video
  readTime?: string,   // for article
  aspect: number,      // thumbnail aspect ratio for masonry
  ogImageUrl?: string, // production: real og:image
}
```

### Persistence (production)

- All thoughts and links stored locally first (SQLite / Core Data / IndexedDB).
- Sync optional, end-to-end encrypted.
- "Private by default · no account required" is a brand promise — honor it.

---

## Design Tokens

### Colors

```
COLOR_BG           = #F0F2F4   /* base wallpaper */
COLOR_TEXT         = #0A0A0B   /* primary text */
COLOR_SECONDARY    = #6B7280   /* secondary text */
COLOR_TERTIARY     = #9CA3AF   /* tertiary text, meta */
COLOR_DIVIDER      = rgba(10,10,11,0.08)
COLOR_DELETE       = #C8362F

/* Glass */
GLASS_WHITE        = rgba(255,255,255,0.55)
GLASS_BORDER       = rgba(255,255,255,0.6)
GLASS_TINT         = rgba(255,255,255,0.4)

/* Accent (one per session, shows in HeroMark halo, library count badge,
   and toast confirmation glyph). Default: blue.) */
ACCENT_BLUE        = #7AA7FF
ACCENT_SAGE        = #9BC4A8
ACCENT_AMBER       = #E8B26A
ACCENT_ROSE        = #E59AAA
ACCENT_VIOLET      = #A89BD8
ACCENT_SLATE       = #9AA4B2
```

### Typography

Single family throughout: **Helvetica Neue** (fallback `Helvetica, Arial, sans-serif`).

Hard contrast between two weights — **800** (headings) and **300** (body). Avoid 400/500/600 except for small-scale UI labels (badges, chips).

| Role | Family | Size | Weight | Letter-spacing | Line-height |
|---|---|---|---|---|---|
| Display title (`mind`, `library`) | HN | 34 | 800 | −1 | 1.0 |
| Wordmark (`quicknote`) | HN | 30 | 800 | −0.7 | 1.0 |
| Section title | HN | 22 | 700 | −0.5 | 1.2 |
| Detail heading | HN | 19 | 700 | −0.4 | 1.3 |
| Body | HN | 15 | 300 | −0.15 | 1.45 |
| Tagline | HN | 15 | 300 | −0.1 | 1.45 |
| Card meta (subtitles) | HN | 12.5–13 | 300 | −0.1 | 1.4 |
| UI label (chip, button, link) | HN | 11–13 | 400–500 | varies | 1 |
| Badge (uppercase) | HN | 10.5 | 500 | 0.8 | 1 |
| Time/duration (numerals) | HN | 9.5–12 | 300–500 | tabular | 1 |

`text-wrap: pretty` on body text. Always.

### Spacing scale

`4 / 6 / 8 / 10 / 14 / 18 / 20 / 28 / 36 / 44 / 52` — irregular, but consistent. Common values: card gap 10, screen padding 16/20, vertical block 18.

### Border radii

```
RADIUS_PILL    = 999px   /* chips, buttons, badges */
RADIUS_CARD    = 16px    /* note cards */
RADIUS_GLASS   = 18px    /* capture bar, glass surfaces */
RADIUS_THUMB   = 14px    /* library thumbnails */
RADIUS_BUTTON  = 14px    /* GlossButton */
RADIUS_DRAG_HANDLE = 999px
```

### Shadows

```
GLOSS_BUTTON_SHADOW = inset 0 1px 0 rgba(255,255,255,0.22),
                      inset 0 -1px 0 rgba(0,0,0,0.5),
                      0 4px 10px rgba(0,0,0,0.18)

CARD_BORDER_SUBTLE  = inset 0 0 0 0.5px rgba(10,10,11,0.07)

BADGE_INSET         = inset 0 0 0 0.5px rgba(10,10,11,0.08),
                      0 1px 2px rgba(0,0,0,0.08)

GLASS_INSET         = inset 0 1px 0 rgba(255,255,255,0.6),
                      inset 0 -1px 0 rgba(255,255,255,0.18),
                      0 1px 0 rgba(255,255,255,0.5)
```

### Backdrop filters (the "glass")

Glass is the brand's structural material. Two recipes:

- **Capture bar / cards:** `backdrop-filter: blur(28px) saturate(180%)` over `rgba(255,255,255,0.55)` background
- **Filter chips backdrop:** `backdrop-filter: blur(12px) saturate(160%)` over a top-heavy gradient `rgba(240,242,244,0.92) → rgba(240,242,244,0)` so scrolled content reads as motion behind the chips, not as a collision
- **Processing overlay:** `backdrop-filter: blur(14px)` over `rgba(240,242,244,0.55)`

In SwiftUI: `.background(.ultraThinMaterial)` or `.regularMaterial`. In iOS UIKit: `UIVisualEffectView` with `UIBlurEffect(style: .systemUltraThinMaterial)`.

---

## Components

### `Mark` — the brand glyph
24×24 SVG. Rounded square (rx=5) with an interior diagonal line from bottom-left to top-right inset corner. Stroke 1.5 default.

### `HeroMark` — Mark with halo
Wraps Mark in a 1.7× radial halo (`radial-gradient(closest-side, ${halo}55, transparent 70%)` blurred 8px) over a "pillow" disc (`radial-gradient(at 35% 30%, #ffffff, #eef1f6 70%, #e4e8ee)`). Optional `breathe` prop runs `qn-breathe`.

### `Glass` — frosted surface primitive
A div with `rgba(255,255,255,0.55)` background, `backdrop-filter: blur(28px) saturate(180%)`, and the `GLASS_INSET` shadow stack. All cards, capture bars, and toasts wrap in `Glass`.

### `GlossButton` — primary CTA
Black gradient pill, 52px tall, full-width by default. Used only on splash. White text 15px weight 500.

### `Badge` — kind indicator
22px pill with a `CatIcon` (category icon, 11px) + uppercase label (10.5px weight 500 letter-spacing 0.8). Shown on every note card and detail header.

### `CatIcon` — category icons
Four monochrome 24×24 SVG icons:
- **task:** circle with checkmark
- **idea:** lightbulb outline
- **note:** document with corner fold
- **link:** chain links *(legacy — no longer rendered in Mind, but kept for Library detail view)*

### `NoteCard`
Glass surface (radius 16, padding 14 16). Header row: Badge + relative time. Body: thought text (15px weight 300). Subtitle (12.5px weight 300 secondary color). Hover/swipe-reveal exposes red delete strip.

### `CaptureBar`
Glass pill (radius 18, blur 28). Input field (15px weight 300, no border, no background, transparent placeholder color `#9CA3AF`). Send button (32×32 black gradient circle) animates in when input has content. Placeholder rotates on a 4200ms interval through: `'anything on your mind…' / 'say it out loud.' / 'what's the residue?' / 'leave it here. come back later.'`

### `FilterChips` (Mind)
Horizontal scroll row of pill chips (height 28, padding 0 10, font 11/500 uppercase letter-spacing 0.3). One active at a time. Frosted gradient backdrop so scrolled notes don't bleed into the row.

### `LibraryGrid`
2-column masonry (gap 10, padding 0 16). Cards distributed alternately to columns, no balancing pass — works because aspect ratios are intentionally varied. Stagger animation: column index × 40ms + row index × 60ms.

### `LinkCard`
Thumbnail (`MockThumb` — gradient block per platform; production: og:image fetched server-side at save time). Platform pill top-left if applicable. Duration badge bottom-right for video. Title 12px weight 500 max 2 lines. Meta row: author or host · readTime.

### `LibraryToast`
Glass pill, slides up 8px and fades in over 240ms. Auto-dismisses after 2400ms. "peek" link navigates to Library.

### `DetailSheet`
Bottom sheet, 92% height, slides up. Drag handle. Backdrop: `rgba(10,10,11,0.18)` with blur 2px. Content: header → title → action items → tags → summary → delete.

---

## Assets

No raster assets — every graphic is SVG drawn in component code. The `MockThumb` library tiles are placeholder gradients **only**; in production, fetch og:image for articles and oEmbed thumbnails for video/social platforms at the moment a URL is captured. Cache locally.

Fonts: Helvetica Neue is preinstalled on iOS/macOS. On Android/web, license Helvetica Neue or substitute with Inter or a similar geometric grotesque (the brand can survive the swap; weights 800/300 contrast is the load-bearing element).

Icons: 4 category icons (task/idea/note/link) drawn inline as SVG in `CatIcon`. The library button uses a 3-stacked-rectangles glyph drawn inline. No icon font.

---

## Implementation Notes

### What to honor strictly

1. **The two-surface model.** Mind is for thoughts you wrote. Library is for things you found. They must feel like *adjacent rooms*, not nested folders. URLs must never enter Mind.
2. **The capture-bar-as-router.** The same input creates both Mind notes and Library entries; the URL regex decides which. The user never picks a destination.
3. **Restraint.** One accent color per session. No additional palette colors. No emoji. No gradients except black-on-black on buttons and the wallpaper field.
4. **Glass.** Capture bar, cards, filter row backdrop, library toast — all use the same material vocabulary. Don't introduce solid surfaces.
5. **Type contrast.** Helvetica Neue 800 vs 300, with `text-wrap: pretty` on every body block.

### What's flexible

- Animation library (Lottie, Reanimated, SwiftUI's spring — pick what your codebase uses)
- Local storage backend (SQLite, Core Data, Realm — anything)
- Classification heuristic (the demo uses regex; production should call your LLM)
- Library page layout (2-col masonry is the spec; on tablet/desktop you can go to 3–4 columns)

### What's missing from the prototype (build these)

- **Real URL detection + og:image fetching.** Currently mocked.
- **Library detail view.** Tapping a LinkCard should open the article in a reader / video in a player. Not in this bundle.
- **Drag-to-dismiss on DetailSheet.** Currently click-to-dismiss only.
- **Real classification.** The demo uses string matching. Production needs an actual model call.
- **Sync.** All state is in-memory in the prototype. Production needs persistence + (optional) sync.
- **Onboarding.** Splash → straight into populated empty state. Decide if you want a tour, or follow the design's bias toward zero-friction entry.
- **Search.** Not in the prototype. Likely needed at >50 notes.
- **Lock-screen widget functionality.** Mock only — wire up actual quick-capture intent.

### Accessibility

- All interactive elements need `aria-label` (the prototype tags the library button correctly; verify the rest).
- Frosted glass must maintain 4.5:1 contrast for body text. The current `#0A0A0B` on `rgba(255,255,255,0.55)` over `#F0F2F4` passes.
- Page dots are decorative — make them non-focusable.
- Honor `prefers-reduced-motion` — disable `qn-breathe`, `qn-pulse`, and the slide-in transitions.
- Dynamic Type / font scaling: the type scale is fixed in the prototype. Production should respond to system text-size preferences.

---

## Questions to resolve with the design team before shipping

1. **Library detail view** — is it a bare in-app browser, an article-mode reader, or a native player per platform?
2. **Capture from outside the app** — share-sheet extension on iOS, intent filter on Android, browser extension on web?
3. **Classifier confidence** — what UI handles the case where the model is unsure between task/idea/note? Today the prototype just picks one.
4. **Multi-line capture** — the bar is single-line. Long-press to expand to a sheet, or auto-grow?
5. **Edit after capture** — the prototype is read-only post-capture. Confirm whether thoughts are editable.
6. **Tags** — currently shown but not editable. Auto-tagged only, or user-tagged?
7. **Account / sync** — "no account required" is a brand promise. How do you enable cross-device without breaking it? (Suggest: optional iCloud/Google Drive sync, no first-party account.)
