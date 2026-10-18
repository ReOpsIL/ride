# Diagnostic overlay — executor cards

Spec: `docs/product/diagnostic-overlay.md` (binding). Mock: `docs/images/diagnostic-overlay.svg`. Executor contract: `plan/roadmap/next-impl.md` sections 0 and 1. Cards run in order, one at a time, each reviewed before the next starts.

## DO-1 Engine labels and parser split (Tier B)

**Goal.** A `Diagnostic` carries every labelled span of rustc's message, its notes with their own spans, and its fixes. Behaviour seen in the app today is unchanged.

**Read first.** Spec sections 2, 4 and 8 in full. `src/check/message.rs`, `parse.rs`, `dedup.rs`, `fixes.rs`, `clang_parse.rs`, `mod.rs`; `src/ffi/check.rs`, `src/ffi/mod.rs`; `src/engine/build_output.rs`; every Rust caller of `Diagnostic` (`grep -rn "Diagnostic {" src tests`). Swift: `app/Ride/Engine/CheckConvert.swift`, `app/Ride/Problems/DiagnosticStore.swift`, every Swift file that builds a `Diagnostic` or `StoredDiagnostic`.

**Create / change.**
- `src/check/message.rs`: deserialize `label`, `line_end`, `column_end`, and `expansion` (with `span` and `macro_decl_name`) on `Span`.
- `src/check/labels.rs`: span to `DiagnosticLabel`. Absolute path through `absolute_string`. Walk `expansion` to the outermost call site whose file is inside the workspace root; set `macro_name` from `macro_decl_name` without the trailing `!`, then add `!`. A chain that never reaches a workspace file keeps the original span.
- `src/check/notes.rs`: child message to `DiagnosticNote { level, message, labels }`. A child span with a label becomes a label. A child span with only a suggestion and no label is not a label.
- `src/check/parse.rs`: orchestration only. One `Diagnostic` per primary span. `secondary` = the message's non-primary spans, source order in the primary's file first, then other files grouped by path. Other primary spans are not repeated.
- `src/ffi/check_labels.rs`: `DiagnosticLabel { path, byte_start, byte_end, line_start, line_end, column, text: Option<String>, macro_name: Option<String> }` and `DiagnosticNote`. `src/ffi/check.rs`: `Diagnostic { level, message, code, primary, secondary, notes, fixes }`, exactly as the spec's 8.2.
- `src/check/dedup.rs`: key on the primary label.
- `src/check/clang_parse.rs` and any other producer: fill `primary`, leave `secondary` and `notes` empty.
- `src/bin/ride_engine/check.rs` and its dispatch in `main.rs`: `ride-engine check <root> [--clippy] [--file <path>]`. Prints, per diagnostic, a header line `<level> <code> <message>` and one indented line per label: `P|S|N <path>:<line>:<col> <text or ->`, then `fix: <title>` per fix.
- Swift: `StoredDiagnostic` keeps `path`, `byteStart`, `byteEnd`, `line`, `column` filled from `primary`, and gains `secondary: [StoredLabel]` and `notes: [StoredNote]`. Put `StoredLabel` and `StoredNote` in a new pure file `app/Ride/Problems/StoredLabel.swift` (no FFI types) and add it to the RideTests Sources phase. `CheckConvert` maps both ways. Every other Swift producer compiles with empty arrays.

**Tests.** `tests/check_labels.rs` (a new file; `tests/check.rs` may not grow past 200 lines). Fixtures are real rustc JSON lines stored under `tests/data/check_labels/*.jsonl`, recorded once by running `cargo check --message-format=json` on small scratch crates outside the repo, then made relative to a fixed root. Required cases: E0382 (three labels, a note naming two spans on another line, a help with a MachineApplicable `.clone()` fix); E0597 (four labels); E0502 (three); E0308 (an expectation span); `unreachable_code` (one secondary); unused imports with two primary spans in one message (two diagnostics, neither repeats the other primary); a label inside `println!` mapped to the call site with `macro_name = "println!"`; a span in the standard library kept with its own path. Assert labels, order, texts, notes and fixes exactly.

**Acceptance.** All gates in contract 1.3, including `bash scripts/build-engine.sh` and `xcodebuild … build test`. `cargo run --bin ride-engine -- check <scratch crate with the E0382 code from the mock>` prints the three labels, the note with two labels and the fix. The Problems panel and underlines behave as before.

**Out of scope.** Anything drawn in the editor. clang notes. Preferences and menus.

## DO-2 Overlay model and drawing (Tier B, after DO-1)

**Goal.** With the mode on At caret, the diagnostic under the caret is drawn as in the mock: secondary and note underlines, label chips under their lines, gutter numbers, note and help rows, a Fix chip. All in file and Off work.

**Read first.** Spec sections 2 to 6 and 9. The mock image. `app/Ride/Editing/DecoratedFragment.swift`, `FoldLayout.swift`, `FragmentRefresh.swift`, `VisionLabel.swift`; `app/Ride/AI/Inline/GhostText.swift`; `app/Ride/Editor/Underlines.swift`, `UnderlineMark.swift`, `GutterView.swift`, `GutterLines.swift`, `RideTextView+Vision.swift`, `RideTextView.swift`; `app/Ride/Preferences/Preferences.swift`; `app/Ride/MenuModel.swift`, `app/Ride/Menus/ViewCommands.swift`; `docs/tui/editor-fragment-refresh.md`; `docs/product/command-inventory.md`.

**Create / change.**
- Pure files under `app/Ride/Overlay/`, all added to the RideTests Sources phase, none referencing FFI types:
  - `OverlayMode.swift`: `enum DiagnosticOverlayMode: String, Codable { case off, caret, all }`.
  - `OverlaySelection.swift`: caret UTF-16 offset, mode and the file's `StoredDiagnostic`s to the active set, with the rules of spec section 3 (any label span containing the caret, or the caret on the primary's line; error beats warning; narrower primary wins; one active diagnostic in caret mode).
  - `OverlayModel.swift`: an active diagnostic plus a line lookup (`(Int) -> Int` from UTF-16 offset to line) and a UTF-8 to UTF-16 mapping to: chips per line (column, text, kind `primary | secondary | note | external`), packed into rows by spec section 5 rule 2 using a column width per chip of `text.count * chipRatio + 2` columns; gutter numbers per line in source order (secondary and primary only); multi-line bracket ranges; note and help rows attached under the primary's line with `jumpLine` when the child has labels; a fix flag when the diagnostic has fixes. Spans in another file become one `external` chip on the primary line.
  - `OverlayShift.swift`: shifts every label of a diagnostic with an edit (reuse `RangeShift`); returns stale when the edit intersects any label span.
- `app/Ride/Overlay/OverlayRows.swift` (AppKit): the decoration. Height = rows × the vision row height. Draws chips with the colours of the mock (theme chrome: error, accent, tertiary for notes, success for Fix) in `Tokens.nsMono` at the vision font size, chip arrow at the span column.
- `DecoratedFragment`: a new `overlay: OverlayRows?`; `bottomMargin` = ghost extra height + overlay height; ghost draws first, then the overlay below it. `make` and `FoldLayout` pass `view.overlayRows(at: paragraph)`.
- `app/Ride/Editor/RideTextView+Overlay.swift`: holds the active set, recomputes it on caret moves and on `CheckService.version` changes, calls `refreshFragments` for the lines whose rows changed (as `refreshVision` does), and answers `overlayRows(at:)`.
- `Underlines`: secondary spans of active diagnostics get a solid accent underline, note spans a dashed tertiary underline. Primary underlines unchanged.
- Gutter: numbers in circles and multi-line brackets for active diagnostics, in a new `GutterOverlay.swift` called from `GutterView` (keep `GutterView.swift` under 200 lines).
- Preference `diagnosticOverlay: DiagnosticOverlayMode = .caret`, decoded with `decodeIfPresent`. `Preferences.swift` is at 200 lines: split it by responsibility first. Settings › Editor gets a picker. `MenuModel` publishes the mode; View › Diagnostic Overlay is a submenu with Off, At Caret, All in File. A shortcut only if `command-inventory.md` shows a free chord; otherwise none, and say so in the hand-back. Update `command-inventory.md` with the new items.

**Tests.** RideTests for `OverlaySelection`, `OverlayModel` (row packing, numbering order, external chip, note rows, folded span attaches to the visible line) and `OverlayShift` (shift, stale). Use the mock's E0382 as one fixture.

**Acceptance.** All gates. Self-test not required in this card. Hand-back states the line count of every new or changed file.

**Out of scope.** Clicks, Esc, hover, Problems-row selection (DO-3).

## DO-3 Interaction and self-test (Tier B, after DO-2)

**Goal.** Spec section 7, the Problems-row behaviour of section 3, and the self-test of section 10.

**Read first.** Spec sections 3, 7 and 10. `app/Ride/Editor/RideTextView+Mouse.swift`, `RideTextView+Keys.swift`; `app/Ride/Problems/ProblemsPanel.swift`, `ProblemFixes.swift`, `DiagnosticDocLink.swift`, `AppState+OpenDiagnostic.swift`; `app/Ride/Editor/PeekController.swift`; `app/Ride/Debug/` self-test steps for Problems and Live (`SelfTestSteps+Problems.swift`, `SelfTestSteps+Live.swift`), the menu coverage gate (`docs/product/command-inventory.md`).

**Create / change.**
- Click a chip or a gutter number: caret to the span start. Click an external chip: Quick Definition at that location. Click Fix: the diagnostic's first fix through the existing fix path, one undo group. Hover a chip: tooltip with the full label, the code and its doc link.
- Esc while an overlay is active and no popup is open hides it until the caret leaves the diagnostic's lines.
- Selecting a Problems row makes that diagnostic active in its editor, whatever the mode, until the caret moves off its lines.
- Self-test steps at the end of the Rust step array, on the fresh copy of `samples/rust-demo`: inject the mock's use-after-move into `src/main.rs` after `fn main() {`, save, wait for the check, put the caret on the primary span and assert three gutter numbers and the chips' texts; click the "value moved here" chip and assert the caret moved; type inside the secondary span and assert the overlay is gone; switch the View submenu to All in File and Off and assert. Claim the new menu items for the coverage gate.
- A demo scene `overlay`, in the pattern of `DemoScene+Diagnose.swift`: on the rust-demo copy it injects the same use-after-move, waits for the check, places the caret on the primary span with the mode At Caret, and settles. Add `"overlay rust-demo"` to the SCENES list in `scripts/screenshots.sh`. Do not run `screenshots.sh`; the reviewer captures the scene and compares it with the mock.

**Acceptance.** All gates, plus the Rust self-test run alone on a fresh copy, with PASS and FAIL counts and every FAIL line in the hand-back.

**Out of scope.** C and C++.
