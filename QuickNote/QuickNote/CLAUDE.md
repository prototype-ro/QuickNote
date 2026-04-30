# CLAUDE.md — QuickNote iOS

## Project Overview
- **App:** Natural language note capture with AI processing
- **Stack:** SwiftUI, iOS 17+
- **Architecture:** MVVM (no Coordinator for v1 — introduce when navigation complexity demands it)
- **Package Manager:** Swift Package Manager only
- **AI Constraint:** Do not modify `.pbxproj`, `.xib`, or `.storyboard` — Xcode project settings are managed manually

## App Domain
- Primary entry point: WidgetKit lock screen widget
- AI model: `claude-haiku-4-5-20251001` via Anthropic API
- Note types: task, idea, note, link
- AI pipeline: classify → extract action items → generate tags → summarize
- See `DESIGN.md` for full visual identity and component guidelines

## Tech Stack
- **UI:** SwiftUI exclusively
- **Networking:** async/await with URLSession
- **Persistence:** SwiftData
- **Testing:** Swift Testing + swift-snapshot-testing

## Coding Standards
- Use `@Observable` macro — no legacy `ObservableObject`
- Prefer value types (structs)
- No force unwrapping (`!`) anywhere
- Enforce `[weak self]` in closures
- Explicit access modifiers on all properties and methods
- SwiftDoc comments on all public APIs

## Architecture Rules
- Diagnose root cause before applying any fix — no quick patches
- Keep individual SwiftUI views under 200 lines — break up early
- Wrap all Claude API calls in a clean `NoteProcessor` service layer
- Model name lives in one constant — never hardcoded inline
- Never hardcode API keys — use environment variables or a local secrets file excluded from git

## File Structure
- `Sources/Features/` — one folder per feature module
- `Sources/Core/` — shared utilities, extensions, global helpers
- `Sources/Services/` — network, persistence implementations
- `Sources/DesignSystem/` — reusable UI components

## Testing
- After writing code, run `xcodebuild test` and fix all errors before finishing
- Test network failures, malformed JSON, and unexpected API responses
- Store all timestamps in UTC — convert to local time only at display layer

## Discipline
- No hacky code left in place — fix immediately or open a tracked issue
- High visual standards: grid alignment, precise typography, minimalism
- See `DESIGN.md` for specifics
