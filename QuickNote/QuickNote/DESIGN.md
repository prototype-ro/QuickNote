# DESIGN.md — Visual Identity & UI System

## Design Philosophy

This app earns attention through restraint. The aesthetic is **cold-premium** —
a near-silent canvas where frosted glass, precise type, and fluid motion do all
the talking. No decorative noise. Every pixel either carries information or
creates space for information to breathe.

Single memorable rule: **if you can remove it and the screen still works, remove it.**

---

## Color System

### Base Canvas
```
Background:      #F0F2F4   — cold off-white, slightly blue-gray tint
Surface:         #FFFFFF   — pure white for card faces
Surface/Glass:   rgba(255, 255, 255, 0.55) + backdrop blur — frosted cards
Overlay:         rgba(240, 242, 244, 0.80) — sheets, modals
```

### Typography Colors
```
Primary text:    #0A0A0B   — near-black, not pure black (softer on cold bg)
Secondary text:  #6B7280   — muted gray for metadata, timestamps
Tertiary text:   #9CA3AF   — placeholders, disabled states
```

### Accent — Monochrome Only
```
Accent:          #0A0A0B   — black. Used for CTAs, active states, the app mark.
Accent/Soft:     #E5E7EB   — light gray for inactive chips, borders
Destructive:     #EF4444   — red, used sparingly for delete only
```

### Type Category Colors (note classification badges)
Badges use tinted glass — no solid fills. Subtle, not loud.
```
Task:            rgba(10, 10, 11, 0.08)  text: #0A0A0B
Idea:            rgba(10, 10, 11, 0.06)  text: #0A0A0B
Note:            rgba(10, 10, 11, 0.05)  text: #0A0A0B
Link:            rgba(10, 10, 11, 0.07)  text: #0A0A0B
```
Category is communicated through a small glyph, not color.

---

## Typography

### Typeface Stack
```
Display / Headings:   "Helvetica Neue" weight 700–800 (Black/Bold)
Body / UI:            "Helvetica Neue" weight 300–400 (Light/Regular)
Mono / Metadata:      SF Mono (system) — timestamps, counts, IDs
```

The tension between Heavy and Light weights of the same family IS the entire
typographic system. No other fonts needed.

### Scale
```
Hero / Screen title:  34pt  weight 800  tracking -0.5
Section heading:      22pt  weight 700  tracking -0.3
Card title:           17pt  weight 600  tracking -0.2
Body:                 15pt  weight 300  tracking  0.0  leading 1.5
Caption / Meta:       13pt  weight 400  tracking  0.1  color: secondary
Micro / Badge:        11pt  weight 500  tracking  0.3  uppercase
```

### Rules
- Screen titles are always heavy. Body copy is always light. Never mix in between.
- No centered text except empty states and onboarding.
- Letter-spacing tightens as weight increases — never loosen a heavy headline.

---

## App Identity Mark

A small geometric glyph — a single thin-stroke symbol that sits at ~20pt in the
nav bar and ~60pt on the splash screen. Character: minimal, almost invisible,
but unmistakably intentional.

Recommended direction: a slim rounded square with a single interior diagonal
line — suggesting a note being written, or a corner being folded. Stroke weight
1.5pt. No fill. Pure black.

This mark never competes with content. It appears only at:
- App icon (on colored background)
- Navigation bar leading position
- Empty state screens
- Onboarding splash

---

## Component System

### Cards — Frosted Glass
```swift
.background(.ultraThinMaterial)
.cornerRadius(16)
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
)
```

Card specs:
- Corner radius: 16pt (cards), 20pt (large feature cards)
- Border: 0.5pt white at 60% opacity — visible only on the glass surface
- Shadow: none. The material effect provides all the depth needed.
- Padding: 16pt horizontal, 14pt vertical
- Spacing between cards: 10pt

### Chips & Tags — Pills
```
Corner radius:   999 (full pill)
Height:          28pt
Padding:         10pt horizontal
Font:            11pt, weight 500, uppercase, tracking 0.3
Background:      rgba(10, 10, 11, 0.06) inactive  |  #0A0A0B active
Text:            #6B7280 inactive  |  #FFFFFF active
Border:          none
```

### Buttons
```
Primary CTA:
  Background:    #0A0A0B
  Text:          #FFFFFF  17pt weight 600
  Corner:        14pt
  Height:        52pt

Secondary:
  Background:    rgba(10, 10, 11, 0.06)
  Text:          #0A0A0B
  Corner:        14pt
  Height:        52pt

Destructive:
  Background:    rgba(239, 68, 68, 0.08)
  Text:          #EF4444
```

### Input Fields — Capture Bar
The capture bar is the most important component in the app.
```
Background:      .ultraThinMaterial
Corner:          18pt (more rounded than cards — it feels inviting)
Border:          0.5pt white at 50% opacity
Min height:      48pt, expands with content up to 120pt
Font:            15pt weight 300 — feels like writing, not typing
Placeholder:     "anything on your mind..." — lowercase, weight 300, tertiary color
Send button:     32pt circle, black fill, white arrow — appears only when text present
```

---

## Motion System

All animations use spring — never linear or easeIn/Out alone.

```swift
let springSnappy   = Animation.spring(response: 0.3, dampingFraction: 0.7)
let springFluid    = Animation.spring(response: 0.5, dampingFraction: 0.8)
let springGentle   = Animation.spring(response: 0.6, dampingFraction: 0.9)
```

### Usage Map
```
Card appear:       springFluid   — scale from 0.96 + fade in
Card dismiss:      springSnappy  — scale to 0.94 + fade out
Sheet present:     springFluid   — slide up from bottom
Processing state:  gentle pulse on app mark, 1.2s loop, scale 1.0→1.06
Tag appear:        springSnappy  — staggered, 0.04s delay per tag
Input expansion:   springGentle  — height grows as user types
```

### Principles
- Every state change is animated. Nothing snaps.
- Duration never exceeds 0.6s for UI transitions.
- The AI processing moment is the most expressive animation — a slow breathing
  pulse on the app mark. This is the one moment the app feels alive.
- No bounce on destructive actions — snappy and resolved only.

---

## Layout System

### Spacing Scale (multiples of 4)
```
4    — icon-to-label gap, badge internal
8    — related elements within a component
12   — component internal padding (compact)
16   — standard padding, card internal
20   — between cards, section gaps
24   — section padding
32   — major section breaks
48   — screen top padding below nav
```

### Screen Structure
```
Navigation bar:    44pt, no visible border — dissolves into background
Content:           horizontal padding 20pt
Bottom bar:        floating above home indicator, glass background
```

### Empty States
Empty states carry the app's personality. Large, centered, minimal:
- App mark at 48pt
- 16pt gap
- 17pt weight 600: "nothing here yet"
- 8pt gap
- 13pt weight 300 secondary: a short, dry, human line. Never "No items found."

---

## Surfaces & Depth

Three depth levels — no shadows, depth through material only:

```
Level 0 — Canvas:    #F0F2F4. Nothing lives here permanently.
Level 1 — Cards:     frosted glass on canvas. Primary content surface.
Level 2 — Sheets:    modal sheets, detail views. Heavier material, more white.
Level 3 — Overlays:  contextual menus. Darkened background + card.
```

---

## Dark Mode

```
Background:      #0C0C0E   — near-black with cold tint
Surface/Glass:   rgba(28, 28, 32, 0.70) + backdrop blur
Primary text:    #F5F5F7
Secondary text:  #8E8E93
Accent:          #F5F5F7
```

Cards become dark-frosted. The feel shifts from cold-clean to cold-cinematic.
Same proportions, same rhythm — different temperature.

---

## What This App Is NOT

- Not warm. Not cozy. Not pastel.
- Not colorful. Color is reserved for system states only.
- Not loud typography. The heaviness is precise, not aggressive.
- Not skeuomorphic. Glass is a material metaphor, not a simulation.
- Not bouncy. Smooth and resolved.

---

## Pinterest Reference Map

- Image 1: premium feel, dark cinematic possibility → dark mode direction
- Image 2: clean white space, minimal filter chips → canvas and chip system
- Image 3: soft white base, glassmorphism, brand personality → card material + app mark
- Image 4: editorial type scale contrast → typography scale
- Image 5: generous whitespace, soft glow, minimal iconography → spacing + glow
- Image 6: layout balance, display vs body contrast → screen composition
