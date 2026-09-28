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

- `LineSplitter` treats only `\r\n` as a terminator, so a bare `\r` (cargo's progress lines) stays inside the line until the next `\n`; the 1.3-1e executor split on bare `\r` too. Land it as its own card with tests on captured cargo output.
- Code vision "N usages" and Find Usages count every same-name identifier from the reference index, including the definition, a trait declaration and its impl (`record` reports 5 with both sample files indexed). Decide whether both should exclude definition sites once `RefKind` filtering (1.3-8a) is used by Find Usages.

# Editor undo follow-ups (2026-09-20, from the undo flake fix)

- `RenameApply.applyBackground` commits through `host.bind(doc)`, which assigns `textView.string` while the document is bound; that rewrite bypasses the edit path and leaves every NSTextView undo record on the stack pointing at ranges of the old text. Route it through `EditorHostView.replaceText` (or drop the records) so a background rename stays undoable.

# Editor (added 2026-09-20, P-6 review)

- `LineEndingMenu` in the status bar writes the global `prefs.lineEndings`; "Convert to LF" on one buffer changes every future save. Make it a per-buffer override with the preference as the default.

# Debug paths (2026-09-20, from the breakpoint spelling fix)

- A stopped frame's path arrives in the spelling the debug info holds (rustc resolves symlinks, clang keeps them), so under a symlinked workspace root `AppState.showStoppedLine` can open a second, read-only buffer for a file already open: `Buffers.buffer(for:)` matches `fileURL` exactly. Match an incoming debugger path to an open buffer through the resolved path, the way `source_path::same_file` does in the engine.

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
- An auto-import is dropped when the user keeps typing before the engine replies.
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

- Typing Enter between items repainted the whole file (the engine's edited-node repaint returned the root node), and the whole-file attribute edit made TextKit 2 re-estimate every wrapped paragraph above the viewport. With soft wrap on, the viewport's first fragment then started below the visible top, leaving a blank band until the next scroll. Fixed at the source: the engine repaints only the leaf tokens that overlap the edit, covered by `tests/repaint.rs` and the self-test "type between labelled items". Other whole-document attribute edits (theme change, reload, format) can still trigger the re-estimation with soft wrap. If that shows up, relocate the viewport in the viewport-did-layout path when its first fragment starts below `visibleRect.minY`.

# Self-test (added 2026-09-28)

- selftest: `type at end` fails deterministically in the full Rust suite ("first fragment at N below visible top M", ~39 layouts) and passes with `--only "type at end"`; reproduced on 13e0ab3 without the oracle work, so an earlier step leaves editor state (folds, soft wrap, scroll) that the viewport check trips on
