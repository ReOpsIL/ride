# Ride — UI Design Plan

| Field | Value |
|---|---|
| Date | 2026-09-09 |
| Status | Phases U0–U5 implemented 2026-09-09; remaining items listed under Open |
| Goal | Ride looks and feels like a professional native macOS IDE: coherent visual system, first-class overlays, an identity, and light/dark parity |
| Review method | `--demo <scene> --frame 1440x900` launch scenes screenshotted per phase (`app/Ride/Debug/DemoScene.swift`), no synthetic input |

## Audit of the current UI (code + screenshots, 2026-09-09)

- Colors are ad-hoc `NSColor` system roles (`controlBackgroundColor`, `windowBackgroundColor`, `.secondary`) mixed with two JSON syntax palettes; no chrome tokens, no spacing/typography scale, no shared border/shadow/radius rules.
- Sidebar is a plain `LazyVStack` with `Label(systemImage: "doc")` for every file; no file-type icons, no header toolbar, no resizing.
- Tab strip is 28 pt with text chips; no active indicator, no hover close, no file icons, no overflow treatment.
- Status bar is monospaced text separated by spaces; no segments, icons, or affordances.
- Completion popup is a bare `NSTableView` in an opaque panel; kind is a text glyph; no doc side panel; hover panel is a wrapped label.
- Quick open, symbol picker and project find are three near-copies of a rounded `VStack` with a dimmed backdrop; no icons, no match highlighting, no footer hints.
- Problems panel and outline are text lists with letter badges; fixed heights.
- Empty editor state is a centered sentence; no welcome view; no app icon; default Preferences form.

## Design principles

1. **One system.** Every color, size, radius and shadow comes from `DesignTokens` and the theme JSON. No literal `NSColor.*Background*` in views.
2. **Native first.** SF Pro for chrome at 11–13 pt, SF Mono for code, SF Symbols for icons, vibrancy materials for overlays, macOS selection and focus conventions. It should look at home next to Xcode and Finder.
3. **Quiet chrome, loud code.** Chrome sits at three background levels (base / raised / overlay) with hairline borders; syntax colors carry the contrast.
4. **Same component, same look.** One `OverlayCard`, one `PickerList` row style, one `KindBadge`, one `PanelHeader`; overlays share placement, animation and keyboard hints.
5. **Light and dark are peers.** Tokens exist for both, contrast ≥ 4.5:1 for text, screenshots reviewed in both.

## Phases

### U0 — Design tokens and theme model

- `app/Ride/Design/DesignTokens.swift`: spacing (2/4/6/8/12/16/24), radii (4/6/8/12), hairline, shadow presets, typography (`ui(11|12|13)`, `mono(size)`), icon sizes.
- Theme JSON gains a `chrome` section: `bg.base`, `bg.raised`, `bg.overlay`, `bg.hover`, `bg.selection`, `border`, `text.primary|secondary|tertiary`, `accent`, `error`, `warning`, `info`, `success`, plus `editor.background|currentLine|selection|caret|gutterText|gutterCurrent|indentGuide`. `Theme` exposes `chrome` and `editor` structs; views read `theme.chrome.*`. Light JSON mirrored.
- `RideColors` SwiftUI bridge (`Color(theme.chrome.bgRaised)`) and an environment object so SwiftUI views update on theme change.
- Contrast test in RideTests for both palettes.

### U1 — Window chrome and layout

- Window: full-size content view, transparent titlebar, unified toolbar with sidebar toggle, project name, Check button, Problems toggle, and a search button that opens Quick Open.
- Sidebar: section header row (project name, New File / Collapse buttons), rows 22 pt with file-type icons (`.rs`, `Cargo.toml`, `.md`, `.lock`, folders open/closed) in tinted SF Symbols, animated chevrons, accent selection, git dot on the right, `target`/hidden dimmed.
- Tabs: 34 pt, file icon, active tab with 2 pt accent top line and editor background, inactive tabs raised background, close button on hover / dirty dot, middle-click close, horizontal scroll with edge fades.
- Panels: outline and problems get a shared `PanelHeader` (icon, title, badges, actions) and are resizable (`HSplitView` / `VSplitView` with min sizes); state persisted in preferences.
- Status bar: 24 pt UI font, left segments (branch, line:col, path), right segments (check pill, index status with 60 pt progress bar, `Spaces: 4`); each segment hoverable and clickable with tooltip.
- Find bar: search field with icon and `n of m` count, chevron buttons, replace toggle, close; Esc restores focus to the editor.
- Empty state: welcome view (app icon, name, Open Folder, recent projects list, shortcut hints).

### U2 — Editor surface

- Gutter: numbers in tertiary color, current line number primary, width fits digit count, diagnostic glyphs (red/yellow) in the gutter, background equal to editor background with a hairline separator token.
- Current line 3 % lift, selection `accent @ 28 %`, caret 2 pt accent, wavy underlines for check errors/warnings and dotted for parse errors.
- Indent guides drawn from line-fragment geometry (behind text), toggle in preferences.
- Curated syntax palettes: dark tuned from the current Dark+ hues; light based on a GitHub-light scheme; both contrast-checked.

### U3 — Overlays

- `OverlayCard`: vibrancy material, 10 pt radius, 1 px border token, 24 pt shadow, 120 ms fade+scale (reduce-motion aware). Used by the completion panel, hover panel and all pickers.
- Completion: 24 pt rows with `KindBadge` (16 pt rounded square, kind letter, per-kind color), matched prefix in accent, signature secondary, origin tertiary; a documentation side card for the selected item (signature, doc paragraph, path); footer `↩ accept · ⇥ accept · esc`.
- Hover: signature in mono, doc in UI font, `path · crate` chip.
- Quick open / symbol picker / symbol-in-file: one `PickerList` with a 16 pt search field, file or kind icon, bold name with highlighted match ranges, dimmed directory or path, selection accent, keyboard-hint footer, empty-state illustration text.
- Project find: query field with `n matches in m files`, file-group headers with icons, line numbers, highlighted match substrings.
- Problems: icon per level, file-group headers, filter toggles for errors/warnings, selected row.

### U4 — Identity and polish

- App icon generated by `scripts/make-icon.swift` (Core Graphics: gradient rounded square, monogram) into `Assets.xcassets/AppIcon`; About window with icon, app and engine versions.
- Preferences as a tabbed window (General / Editor / Tools) with SF Symbol tabs and a theme picker showing palette swatches.
- Help ▸ Keyboard Shortcuts sheet listing every binding.
- Empty and error states: no folder, no rust-src (with the `rustup component add rust-src` hint), index error, check failed.

### U5 — Light parity and accessibility

- Every demo scene screenshotted in light; fix contrast and color mismatches.
- Focus rings on custom controls, accessibility labels on icon buttons, respect Reduce Motion and Increase Contrast.
- Font-size preference applies to editor and, optionally, chrome.

## Acceptance per phase

Each phase ends with the full scene set captured at 1440×900 (`editor`, `completion`, `hover`, `quickopen`, `symbols`, `find`, `problems`, `outline`, `light`), reviewed against the principles above, plus green `xcodebuild build test`.

## Status (2026-09-09)

| Phase | State |
|---|---|
| U0 tokens | Done: DesignTokens, chrome/editor/syntax JSON sections, ThemeStore, contrast tests |
| U1 chrome | Done: compact unified toolbar, sidebar with file icons, 34 pt tabs, PanelHeader, resizable panes, segmented status bar, find bar, welcome view |
| U2 editor | Done: gutter with diagnostic dots, indent guides, palettes, underlines via text storage |
| U3 overlays | Done: OverlayCard/Panel, KindBadge, PickerCard/List with match highlighting, completion doc card, hover card, project find groups, problems filters |
| U4 identity | Done: app icon, About, tabbed Preferences with swatches, shortcuts panel, empty/error states |
| U5 parity | Done: light captures for every scene, accessibility labels, Increase Contrast, Reduce Motion |

Open: focus rings on custom controls; About and Shortcuts windows have no demo scene; editor split.
