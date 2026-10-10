# App follow-ups (see plan/roadmap/improve-extend.md)

- A3 split: EditorJump is a singleton bound to the last-attached pane; rework before adding a second pane
- Snippet mode ends when a nested completion is accepted inside a placeholder and that hit is itself a snippet (the outer stops are dropped)
- Signature help hides on any `)`; inside nested calls the outer signature only returns on the next `,`
- Sparkle or manual update check (Phase 5)
- universal (x86_64) xcframework slice (Phase 5)
- Outline shows occasional blank rows on large files (items with empty names); filter or name them
- New File in the workspace tree still defaults to `untitled.rs`; reuse the save panel's language picker
- Problems panel keeps a C file's diagnostics until that file is checked again; drop them when the buffer closes or the file is deleted
- Cheat sheet pinned mode refetches on every caret move (one engine call each); add a per-line debounce if it shows up in profiles
- Cheat sheet rows show the template's first lines joined with ⏎; a syntax-highlighted preview through the engine's highlighter would read better

# Must-have follow-ups (2026-09-10, see plan/roadmap/must_have.md)

- Replace in Project with a preview sheet
- Project tree: ⌫ deletes and ↩ renames the selected node; Recent Locations picker
- Line endings: a preference to convert CRLF to LF on save (today the original ending is preserved)

# Run output (added 2026-09-20, dropped from 1.3-1e at merge)

- Code vision "N usages" and Find Usages count every same-name identifier from the reference index, including the definition, a trait declaration and its impl (`record` reports 5 with both sample files indexed). Decide whether both should exclude definition sites once `RefKind` filtering (1.3-8a) is used by Find Usages.

# Editor undo follow-ups (2026-09-20, from the undo flake fix)

- `RenameApply.applyBackground` commits through `host.bind(doc)`, which assigns `textView.string` while the document is bound; that rewrite bypasses the edit path and leaves every NSTextView undo record on the stack pointing at ranges of the old text. Route it through `EditorHostView.replaceText` (or drop the records) so a background rename stays undoable.

# Search (added 2026-09-20, screenshot review)

- Find in Project lists one row per match, so a line with two matches (`let mut counter = Counter::new();`) appears twice with every match highlighted in both. Group results per line with a match count instead.

# Multi-project follow-ups (2026-09-23, see docs/product/multi-project.md)

- Build diagnostics are one slot (`DiagnosticStore.build`): building project B drops the build problems of project A. Key them by project root like cargo check diagnostics.
- Cargo diagnostics of a project that disappears on rescan stay in the Problems panel until the app restarts; drop the slots of roots no longer listed.
- Run configurations are keyed by target name only; two projects with a target of the same name share one configuration. Key them by project root and target.

# Full review follow-ups (2026-09-27)

- `xcodebuild test` from an empty derived-data folder fails ("Unable to resolve module dependency 'Ride'"): ten RideTests files `@testable import Ride` but RideTests has no target dependency on Ride. CI runs `build test` so it passes there. Add the dependency, or drop the imports and compile those files into RideTests.
- Debugger: `debugLaunch` still runs on the main thread; continue/step stay synchronous on purpose so a stop event cannot arrive before the running state is set. The engine should emit `Running` itself after a continue/step response, then these calls can leave the main thread.
- Breakpoints do not move with a renamed file (tree rename updates open tabs only).
- `rebind()` does not give the engine session the new path when a renamed file keeps its language.
- `DebugChain.expect` uses the previous `runId` when a run is queued behind a running one.
- Layout panel sizes live in both `Preferences` and `LayoutState` (defaults are now only in `LayoutState.defaults`); embedding `LayoutState` in `Preferences` needs flat coding to keep old prefs loading.
- `HierarchyQuery.children` and `TestMarkers` still read sessions off `SessionService.read`.
- Slow workspace reads (usages, hierarchy, definitions) can see edits made while they run and still show their results.
- Build diagnostics are not de-duplicated per build (`cargo test`/`--all-targets` compile the lib twice): `parse_cargo_line` is stateless per line, so dedupe in `BuildSession`/`DiagnosticStore`.
- Cargo messages without a primary span (missing native library, some E-codes) are dropped; `Diagnostic.path` is required, so decide a Swift-side home for file-less diagnostics first.

# Menu coverage follow-ups (2026-09-27, see docs/product/command-inventory.md)

- Not reachable by the self-test yet: Install Tools › Install Selected and the tool checkboxes (would install software), Settings › Install `ride` command and Test connection (system install / network), AI answer panel header buttons, the project switcher (the demo samples hold one project each), real NSAlert buttons (steps answer through `DialogScript`), the SwiftTerm terminal itself (a probe view stands in).
- Exception breakpoint filter changes do not reach a live debug session (the engine has no call to set exception breakpoints mid-session), and filter states are not saved in the workspace.
- The Pause step accepts any stop reason except breakpoint/step because lldb-dap reports a pause as "exception"; map it to a pause state in the engine's DAP layer.
- Quick Documentation shows two rows (⌃J and F1): SwiftUI Commands have no alternate items; ⌃? needs Shift on US layouts.
- C++ Generate offers members that already exist (the engine does not check).
- Navigate › Go to Symbol in Project has no ⌘C copy-path test; there is no View item to reopen a hidden Hierarchy panel; Save All skips untitled buffers silently.
- Two self-test key helpers do the same job: `SelfTestKeys` (KeyCombo glyphs, posts events) and `SelfTestKey` in `SelfTestKeyPress.swift` (fixed enum, sends to a view/sheet). Fold `SelfTestKey` into `SelfTestKeys`.
- `DiagnosticTidyTests` and `DiagnosticStoreTidyTests` cover the same tidy slot from two angles; merge them.

# Soft-wrap viewport gap (2026-09-27)

- Resolved 2026-10-04: style writers (`HighlightApply`, `Underlines`) now settle the layout they invalidate above the viewport and keep the top line anchored (`RideTextView+Styles.swift`, see docs/tui/editor-fragment-refresh.md).

# Self-test (added 2026-09-28)

- selftest: `type at end` failed in the full Rust suite ("first fragment at N below visible top M"); cause was whole-range style invalidation above the viewport, fixed 2026-10-04 with `editStyles`.

# Popup stacking (2026-10-03)

- Completion, cheat sheet and signature help each keep the caret line plus `CompletionPlacement.clearLines` clear, but they place independently. When the cheat sheet flips to the side opposite the completion list, it and signature help can land on the same side and overlap. Fold the three into one stack planner that hands out lanes above and below the caret band.

# Outline tree (2026-10-03)

- Markdown headings stay flat in the outline: a heading's range covers only its line. Nest by heading level (engine section ranges or an app-side level rule).
- C++ out-of-class definitions (`void Circle::area() {}`) do not carry an `OutlineItem.scope`, so they sit at top level instead of under their class.
- Cheat sheet at member-access sites opens unrelated sections: after `"a.b".split('.').` (Rust) it lists Control flow, after `it->` (C++) Template utilities and traits. Seen in the `members` / `cppmembers` demo scenes; the demo disables the sheet there.

# Git follow-ups (added 2026-10-06, see docs/product/git.md)

- Run RideTests and the in-app self-test on the Git app layer (it builds and the diff view was checked by hand)
- Diff gutter markers per buffer with revert hunk (plan/roadmap/level-up.md 2.0-1); needs the engine diff of buffer text against the index
- Stage and unstage single hunks from the diff view
- History, blame, stash, merge (2.0-2) and the three-pane conflict resolver (2.0-3); conflicted files only show `!` today
- Side-by-side diff mode; word-level change marks inside modified lines
- Self-test for commit, branch and push against a scratch repository instead of menu-coverage exemptions

# Panels (added 2026-10-06, AI/git visual review)

- Changes and Usages panels open at a fixed split position (300 / 220) but their heights are not saved; the other bottom panels each carry a height through `Preferences`, `LayoutState` and `AppState+Layout`. Replace the per-panel fields with heights keyed by a bottom-panel enum so a new panel cannot ship without one.
