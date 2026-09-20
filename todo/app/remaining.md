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

- Folding: gutter chevrons and a fold-state indicator; folds are only reachable from the Code menu and ⌥⌘← / ⌥⌘→ today
- Matching brace: highlight the pair under the caret as a rendering attribute (the jump exists)
- Reformat Selection (`clang-format --lines`, rustfmt on the enclosing item), Move Statement, Complete Current Statement
- Replace in Project with a preview sheet
- Project tree: ⌫ deletes and ↩ renames the selected node; Recent Locations picker
- Line endings: a preference to convert CRLF to LF on save (today the original ending is preserved)

# Audit follow-ups (2026-09-17, bound-host review)

- Breakpoints are stored as absolute line numbers (`Breakpoints.swift`) and never shifted by edits; `EditorCoordinator.textDidChange` shifts folds and underlines but not breakpoints, so inserting lines above a breakpoint moves it onto a different statement. Shift them through the same edit, then re-sync to the debugger.
- Format, Reload and Replace in Project replace the whole text through `EditorHostView.replaceText`, which clears the document's undo stack instead of registering an undoable step. Route whole-text replacement through `replaceText(in:with:)` so ⌘Z restores the pre-format text.
- `document.highlights` keeps engine byte offsets and is never shifted after an edit (`SessionService+Paint.swift`), so `HighlightApply.restyle` on re-attach paints stale ranges until the next engine paint. Shift spans with the edit or drop them on edit.
- UsageVision ("N usages" editor overlay) has a pure model and tests but no view (see `plan/roadmap/next-1.3.md`).
- Files over 200 lines to split: `SelfTestSteps+Cpp.swift`, `SelfTestSteps+Rust.swift`, `RideTextView.swift` (apply* helpers), `AppState.swift` (overlay flags), `PeekPanel.swift` (`PeekChrome`), `RootView.swift` (`DetailColumn`), `Buffers+File.swift` (new/open/close workspace).
- 17 copies of the `guard let engine = RideEngineClient.shared.engine` + background queue + main hop prologue; add `RideEngineClient.withEngine(_:then:)`.

# Run output (added 2026-09-20, dropped from 1.3-1e at merge)

- `LineSplitter` treats only `\r\n` as a terminator, so a bare `\r` (cargo's progress lines) stays inside the line until the next `\n`; the 1.3-1e executor split on bare `\r` too. Land it as its own card with tests on captured cargo output.
- Code vision "N usages" and Find Usages count every same-name identifier from the reference index, including the definition, a trait declaration and its impl (`record` reports 5 with both sample files indexed). Decide whether both should exclude definition sites once `RefKind` filtering (1.3-8a) is used by Find Usages.

# Editor undo follow-ups (2026-09-20, from the undo flake fix)

- `RenameApply.applyBackground` commits through `host.bind(doc)`, which assigns `textView.string` while the document is bound; that rewrite bypasses the edit path and leaves every NSTextView undo record on the stack pointing at ranges of the old text. Route it through `EditorHostView.replaceText` (or drop the records) so a background rename stays undoable.
- Format, Reload and Replace in Project still clear the undo stack (see the bound-host review item above); they now share `applyChanges`, so registering them as one step is a small change.

# Editor (added 2026-09-20, P-6 review)

- `LineEndingMenu` in the status bar writes the global `prefs.lineEndings`; "Convert to LF" on one buffer changes every future save. Make it a per-buffer override with the preference as the default.

# Debug paths (2026-09-20, from the breakpoint spelling fix)

- A stopped frame's path arrives in the spelling the debug info holds (rustc resolves symlinks, clang keeps them), so under a symlinked workspace root `AppState.showStoppedLine` can open a second, read-only buffer for a file already open: `Buffers.buffer(for:)` matches `fileURL` exactly. Match an incoming debugger path to an open buffer through the resolved path, the way `source_path::same_file` does in the engine.
