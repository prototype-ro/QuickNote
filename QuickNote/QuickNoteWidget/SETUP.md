# QuickNoteWidget — Xcode setup (~3 min, manual)

Claude wrote all the widget code; this is the part that touches the `.pbxproj`
(target, signing, entitlements, URL scheme) and must be done in Xcode.

## Files already written (in `QuickNoteWidget/`)
- `QuickNoteWidgetBundle.swift` — `@main` bundle
- `WidgetProvider.swift` — timeline provider + visual tokens + mark
- `GlanceWidget.swift` — home-screen / StandBy (systemSmall, systemMedium)
- `CaptureWidget.swift` — lock-screen accessories (circular, rectangular, inline)
- `QuickNoteWidget.entitlements` — app group
- `Sources/Services/WidgetSnapshot.swift` — **shared** (already in app target)

## Steps

1. **Create the target.** File → New → Target → **Widget Extension**.
   - Product Name: `QuickNoteWidget`
   - **Uncheck** "Include Live Activity" and "Include Configuration App Intent"
     (the widgets use `StaticConfiguration`).
   - Finish → **Activate** the scheme when prompted.

2. **Remove Xcode's template files.** The target ships with template `.swift`
   files (e.g. `QuickNoteWidget.swift`, `AppIntent.swift`). Delete them (Move to
   Trash). Keep the generated `Assets.xcassets` and `Info.plist`.

3. **Add the real files to the target.** If Xcode created its folder at the same
   path, the 5 files above may already sit there. Select each in the Project
   navigator → File Inspector → **Target Membership** → check `QuickNoteWidget`.
   If they're not in the project, drag them in (Add to target: `QuickNoteWidget`).

4. **Share the snapshot model.** Select `Sources/Services/WidgetSnapshot.swift`
   → File Inspector → Target Membership → check **both** `QuickNote` and
   `QuickNoteWidget`.

5. **App group on the widget.** Select the `QuickNoteWidget` target → Signing &
   Capabilities → **+ Capability → App Groups** → add
   `group.com.prototype.QuickNote`. (Or set its entitlements file to
   `QuickNoteWidget/QuickNoteWidget.entitlements`.)

6. **Register the URL scheme on the APP target.** Select the `QuickNote` target →
   **Info** tab → **URL Types** → **+** → URL Schemes = `quicknote`.
   (Enables `quicknote://capture` and `quicknote://inbox` deep links.)

7. **Build & run.** Long-press the home screen / lock screen → add the QuickNote
   widget. Tapping the lock-screen capture widget should open the app with the
   capture bar focused; the home widget shows your latest thought + count.

## How data flows
- The app writes a `WidgetSnapshot` (latest text, type, count, one resurfaced
  note) to the app group on every note change, then calls
  `WidgetCenter.reloadAllTimelines()`.
- The widget reads only that snapshot — it never touches the SwiftData store.
