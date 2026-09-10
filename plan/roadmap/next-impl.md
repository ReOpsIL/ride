# Ride — Implementation plan for a delegated model (2026-09-10)

Derived from `next.md`. That file says *what* and *why*; this file says *exactly what to do*, in units small enough that a second, cheaper model (the "executor") can take one unit, finish it, prove it with the repo's own gates, and hand back a reviewable diff. Design decisions are made here, not by the executor.

| Field | Value |
|---|---|
| Executor | Any capable coding model (written for Grok 4.6; nothing here is model-specific) |
| Reviewer | A stronger model or the maintainer, before merge, on every unit |
| Unit of work | One task card = one branch = one PR, under ~400 changed lines |
| Judge | The gates in §1.3, not the executor's own description of the change |

## 0. Delegation tiers

Every card carries a tier. Assign work by tier, not by release order.

| Tier | Meaning | Rule |
|---|---|---|
| **A** | Bounded, testable, design fixed in the card | Delegate freely. Review the diff and the test output. |
| **B** | Bounded, but touches shared state or an existing state machine | Delegate only with the card's design followed literally; reviewer reads every changed file. |
| **C** | Architectural: new module boundaries, cross-cutting refactors, long-lived protocols | Keep on the strong model. The executor may do the follow-up cards that hang off it. |

Summary by release:

| Release | A | B | C |
|---|---|---|---|
| 1.1 | 1.1-2, 1.1-3, 1.1-4 (a, b, c, e, f, g), 1.1-5, 1.1-6a, 1.1-7, 1.1-8, 1.1-9a | 1.1-1b, 1.1-4 (d, h, i), 1.1-6b, 1.1-9b, 1.1-10 | 1.1-1a |
| 1.2 | 1.2-4a (output parsers), 1.2-5 | 1.2-1 (per project kind), 1.2-2, 1.2-3, 1.2-4b | 1.2-6 |
| 1.3 | 1.3-3 (per generator), 1.3-5 | 1.3-2, 1.3-6, 1.3-8 | 1.3-1, 1.3-4, 1.3-7 |
| 2.0 | 2.0-4 | 2.0-1, 2.0-2, 2.0-3 | diff engine |

Cards for 1.2 are written at the same depth as 1.1 only where the design is already settled; 1.3 and 2.0 get tier assignments and a sketch, because the code they touch will have moved by then. Write their cards when the release starts.

## 1. Executor contract

Read this section before every card. It is the whole difference between a mergeable diff and a rewrite.

### 1.1 Repository rules (from `AGENTS.md`, enforced in review)

- One module, one responsibility. A source file over ~200 lines or a function over ~40 lines is a defect: split before adding.
- **No comments, docstrings, TODO strings or banners in source.** Names carry meaning. Prose goes to `docs/`, `plan/` or `todo/`.
- Rust: `Result` over panics, no `unwrap` in library code (`tests/` may unwrap), explicit error types (`src/error.rs`).
- Root cause, not symptom: read the module and its callers before editing. No guard clauses that hide bad state.
- Do not edit `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/README.md` unless the card says so.

### 1.2 Project facts the code does not tell you

- **RideTests compiles a subset of app files.** Test-target sources are listed by hand in `app/Ride.xcodeproj/project.pbxproj` (the `RideTests` Sources phase). A pure Swift file you want to test must be added there and **must not reference generated FFI types** (`Engine`, `CompletionHit`, `SessionOpen`, anything from `app/generated/`). Put FFI-facing code in a separate file from the pure logic.
- **Menus observe `MenuModel` only.** `.commands` blocks in `app/Ride/Menus/*.swift` must not read `AppState`; reading it makes SwiftUI rebuild the open menu. Publish what a menu needs on `MenuModel` (`app/Ride/MenuModel.swift`).
- **No UI automation while the maintainer is at the keyboard.** Do not drive the app with AppleScript, `osascript`, Accessibility scripting or synthetic key events. Verify through `cargo test`, the RideTests target and the in-app self-test scene (`Ride --demo selftest`, see `app/Ride/Debug/`).
- The engine is a Rust crate exposed to Swift through UniFFI. Any new engine call is: a method on `Engine` in `src/engine/`, a record in `src/ffi/`, then `scripts/build-engine.sh` to regenerate `app/generated/` and the xcframework. Swift code cannot see an engine change until that script has run.
- A full reindex of the live index takes ~50 s; tests use a temp index dir (`tests/samples.rs::engine()`), never the live one.
- Tree-sitter grammars and versions are pinned in `Cargo.toml` (`tree-sitter = "=0.27.0"`); do not bump them inside a feature card.

### 1.3 Gates (all must pass before a card is "done")

```
cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
cargo test
bash scripts/build-engine.sh                      # only when src/ffi or src/engine changed
xcodebuild -project app/Ride.xcodeproj -scheme Ride -configuration Debug \
  -derivedDataPath target/xcode -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO build test
```

Plus the self-test scene when a card says so. Report the output of every gate verbatim in the hand-back; "tests pass" without output is not a hand-back.

### 1.4 Hand-back format

```
Card: <id>
Changed: <files>
Added tests: <files or test names>
Gates: <pasted tail of each command>
Not done / deviations: <what the card asked for that is missing, and why>
Design questions: <anything the executor had to guess>
```

Stop and hand back instead of guessing when: a card's named file no longer exists, a step needs a new engine record that the card did not specify, a change would exceed ~400 lines, or a gate fails for a reason outside the card's files.

### 1.5 Card template

Every card has: **Tier · Goal · Read first · Create / change · Steps · Acceptance · Out of scope**. "Read first" is mandatory reading before the first edit.

---

## 2. Release 1.1 — Trust

### 1.1-1a Pane registry (Tier C, strong model)

**Goal.** Replace the `EditorJump` singleton (`app/Ride/Editor/EditorJump.swift`, 17 call sites across `Search/`, `Navigate/`, `Editing/`, `Debug/`, `Editor/`, `AppState+*`) with a registry that knows which pane is focused and which pane holds which buffer.

**Design (fixed).**
- `EditorPanes` (observable, owned by `AppState`): `panes: [PaneId: PaneHost]`, `focused: PaneId`, `func host(for: BufferId) -> PaneHost?`, `func focusedHost() -> PaneHost?`.
- `PaneHost` wraps the current `EditorHostView` and carries the per-pane state that today lives on `EditorJump` (weak `view`, weak `host`) plus the pane's tab list.
- The four `EditorJump` operations (`jump(byte:)`, `select`, `jump(toLine:)`, `replaceText`) become methods on `PaneHost`. Callers that mean "the pane the user is in" call `panes.focusedHost()`; callers that mean "the pane showing file X" call `panes.host(for:)`. Each of the 17 call sites is classified one way or the other in the PR description.
- Tabs move from a single `TabStrip` to one strip per pane; `Buffers` stays global (a buffer can be open in two panes).
- Popups (hover, completion, cheat sheet, signature help) are already per `RideTextView`; verify they are, and fix any `static`/shared controller that assumes one text view.

**Acceptance.** Single-pane behaviour unchanged: `--demo selftest` passes all checks; RideTests `NavigationTests`, `NavigationHistoryTests` pass; `EditorJump.swift` is deleted.

### 1.1-1b Split commands (Tier B, after 1.1-1a)

**Goal.** Open-in-split, ⌘\ toggle, close-split, drag a tab between strips; Switch Header/Source (F10) opens the sibling in the other pane when a split exists.

**Read first.** `app/Ride/Editor/EditorPane.swift`, `TabStrip.swift`, `TabItem.swift`, `app/Ride/Navigate/SiblingSource.swift`, `app/Ride/Menus/ViewCommands.swift`, `MenuModel.swift`, the 1.1-1a PR.

**Create / change.** `app/Ride/Editor/SplitLayout.swift` (pure layout state: `enum Split { single, horizontal(ratio) }`, in RideTests), `EditorPane.swift` (render one or two hosts in an `HSplitView`), `ViewCommands.swift` (menu items read `MenuModel.hasSplit`), `TabStrip.swift` (drag source and drop target using `NSItemProvider` with the buffer id as a string).

**Acceptance.** RideTests `SplitLayoutTests`: toggle, close-right-pane focuses left, ratio clamped to 0.2…0.8. Self-test scene: new step opens a split, opens `include/geo.h` from `src/geo.cpp` with F10, asserts the two panes show different paths (extend `app/Ride/Debug/SelfTestSteps.swift`).

**Out of scope.** Vertical split, more than two panes, per-pane find bar.

### 1.1-2 Persistent workspace state (Tier A)

**Goal.** Reopening a workspace restores open tabs, the focused tab, caret and scroll position per file, fold state per file, sidebar and panel sizes and visibility, and the split (once 1.1-1b exists).

**Read first.** `app/Ride/Workspace/Workspace.swift`, `RecentProjects.swift` (how the support directory and the per-root key are derived today), `AppState+Layout.swift`, `AppState+Launch.swift`, `Editor/Buffers.swift`, `Editing/FoldSet.swift`.

**Design (fixed).**
- One JSON file per workspace root at `<support dir>/workspaces/<sha256 of root path>.json`, written through a 500 ms debounce on any change and on quit.
- `WorkspaceState: Codable` in `app/Ride/Workspace/WorkspaceState.swift` (pure, in RideTests): `version: Int`, `tabs: [TabState]` (`path`, `caretByte`, `scrollLine`, `folds: [UInt32]` start bytes), `focusedPath`, `layout: LayoutState` (sidebar width, panel heights, visibility flags), `split: SplitState?`.
- `WorkspaceStateStore` (`Workspace/WorkspaceStateStore.swift`): load, save, the debounce, file I/O; not in RideTests.
- Restore is best-effort: a tab whose file no longer exists is skipped; a caret past EOF clamps; a fold whose start byte is no longer a fold start is dropped (FoldSet already has the ranges).
- `version` starts at 1; an unknown version is ignored, never migrated.

**Acceptance.** RideTests `WorkspaceStateTests`: round-trips through `JSONEncoder`/`Decoder`; missing optional fields decode; version mismatch yields nil. Self-test step: open two files, set a caret, save state, reload state, assert the tabs and caret. Manual check by the reviewer: quit and relaunch on `samples/cpp-demo`.

**Out of scope.** Undo history, unsaved buffer contents (Revert prompt stays), per-window state for multiple windows.

### 1.1-3 Update check and universal build (Tier A, two PRs)

**3a Universal engine and app.** `scripts/build-engine.sh`: build `--target x86_64-apple-darwin` as well, `lipo -create` the two static libs into one before `xcodebuild -create-xcframework`; `scripts/release.sh`: `-destination 'generic/platform=macOS'` and `ARCHS="arm64 x86_64"`; zip name loses the `-arm64` suffix. CI (`.github/workflows/engine.yml`): add the x86_64 target to `dtolnay/rust-toolchain` `targets`. Acceptance: `lipo -info` on the built lib lists both architectures; CI green.

**3b Sparkle update check.** Add Sparkle 2 as a Swift package to `app/Ride.xcodeproj`; `SUFeedURL` and `SUPublicEDKey` in `Info.plist` (key from `RIDE_SPARKLE_PUBLIC_KEY` in the environment at release time, placeholder in the repo); "Check for Updates…" in the app menu wired to `SPUStandardUpdaterController`; `scripts/release.sh` runs Sparkle's `generate_appcast` over `target/release-app/` when `RIDE_SPARKLE_PRIVATE_KEY_FILE` is set and writes `appcast.xml` next to the zip. Acceptance: release script produces zip + appcast on a machine with the keys; without keys it prints one line and skips; app builds with the menu item present. Out of scope: hosting the appcast, delta updates.

### 1.1-4 Editor leftovers (Tier A unless marked)

Each letter is its own PR. Pure text logic lives in `app/Ride/Editing/` and joins RideTests (see §1.2); syntax-dependent logic is an engine session query tested with caret-marker fixtures in `tests/editing.rs`.

| # | Item | Tier | Where | Design | Acceptance |
|---|---|---|---|---|---|
| a | Fold chevrons | A | `Editor/GutterView.swift`, `Editing/FoldController.swift` | Gutter draws a chevron on each fold-start line from `FoldSet`; click toggles through the existing fold command; folded rows show `…` after the line (already rendered by `FoldLayout`). | `FoldSetTests` extended with `isFoldStart(line:)`; self-test step folds via the gutter model (not a click). |
| b | Bracket-pair highlight | A | `Editing/BracketPairing.swift` (pair lookup exists), new `Editor/BracketHighlight.swift` | On selection change, if the caret touches a bracket, add a temporary background attribute to both; remove on next change. Skip inside strings and comments using the existing `matching_brace` engine query. | `BracketPairingTests`: pair positions for `( [ { < >` including nested; unmatched returns nil. |
| c | Reformat Selection | A | `src/check/fmt.rs`, `src/engine/tools.rs` (`format_c`, `format_rust`), `Menus/CodeCommands.swift` | C/C++: `clang-format --lines=<from>:<to>`. Rust: rustfmt has no range flag; format the enclosing item (outline range from the session) and splice the result. Makefile and others: whole file. | `tests/check.rs`: a C snippet with two functions, only the selected one changes; a Rust file where only the enclosing `fn` is reformatted. |
| d | Move Statement Up/Down | B | `src/highlight/editing/`, `src/engine/editing.rs`, `Editing/LineOps+Move.swift` | New session query `statement_range(byte) -> (start, end)`: the smallest tree-sitter node whose kind is in the language's statement set (Rust: `expression_statement`, `let_declaration`, `item` kinds; C/C++: `*_statement`, `declaration`, function definitions). Move swaps the statement with the previous or next sibling statement; the app applies it as one edit in one undo group. | `tests/editing.rs` caret fixtures for each statement kind; `LineOpsTests` for the swap given two ranges. |
| e | Complete Statement | A | `src/engine/editing.rs`, `Editing/EditorCommands.swift` | ⇧⌘↩: if the line's statement lacks `;` (Rust `let`/expression, C declaration/expression), append it; if the caret is in an `if`/`for`/`while`/`fn` header without a body, append ` {\n\n}` and place the caret inside; otherwise start a new line. | Caret fixtures for the three outcomes in each language. |
| f | Replace in Project | A | `Search/ProjectFind.swift`, `ProjectFindModel.swift`, new `Search/ProjectReplace.swift` (pure: applies `[FileHit]` + replacement → `[FileEdit]`, in RideTests) | Replace field under the project find field; a preview sheet lists files and count, each file can be unticked; apply writes files through `Buffers` if open, else to disk, then triggers the watcher. | `ProjectReplaceTests`: regex and literal, multiple hits per line, an unticked file is untouched. |
| g | ⌫ and ↩ in the tree | A | `Workspace/ProjectTreeView.swift`, `TreeActions.swift` | ⌫ runs the existing Delete action with its confirmation; ↩ starts the existing rename. Key handling on the outline view, not in `.commands`. | Reviewer's manual check; self-test can assert the actions are reachable through the tree model. |
| h | Nested snippet stops | B | `Completion/SnippetSession.swift`, `CompletionSession+Snippet.swift` | When a completion accepted inside a placeholder is itself a snippet, push the new stops onto a stack; when the inner session ends (last stop or Esc), pop and resume the outer stops with their ranges shifted by the inserted delta (`RangeShift`). | `SnippetParserTests` unchanged; new `SnippetStackTests` on the pure stack with shift arithmetic. |
| i | Outer signature after `)` | B | `Completion/SignatureHelpController.swift` line ~29 | On `)`, instead of hiding, re-query `signature_help` at the caret; hide only when the engine returns none. The engine already resolves the enclosing call. | Self-test step: type `f(g(1), ` and assert the signature shows `f`; caret fixture in `tests/edits_and_signatures.rs` for the nested case. |

### 1.1-5 Extension-less C++ headers (Tier A)

**Read first.** `src/highlight/syntax.rs` (`Lang::for_path`), `src/highlight/header.rs` (`is_cpp_header`), `src/discover/system_includes.rs`, `app/Ride/Editor/BufferLanguage.swift`, `tests/system_headers.rs`.

**Design.** `Lang::for_path` returns `None`-equivalent for an extension-less file today; add `Lang::sniff(path, text, system_dirs)`: a file with no extension whose path is under one of the cached system include directories, or whose text passes `is_cpp_header`, is `Lang::Cpp`. `open_session` uses it and reports the language in `SessionOpen.lang` (already there). The app marks a buffer read-only when its path is under a system include directory (`BufferDocument` gets `isReadOnly`, the text view refuses edits with a beep, the tab shows a lock glyph).

**Acceptance.** `tests/system_headers.rs`: opening `<sysroot>/c++/v1/vector` (skipped when clang is absent) yields `Lang::Cpp` and an outline with `class vector`; a no-extension file under `samples/` with plain text stays `Lang::Plain`. RideTests `BufferLanguageTests`: read-only flag from a system path.

### 1.1-6 Problems hygiene and project C check

**6a Drop stale diagnostics (Tier A).** `AppState+Check.swift`, `Problems/ProblemsPanel.swift`: diagnostics are keyed by path; on buffer close or file deletion remove that path's C diagnostics (Rust diagnostics come per `cargo check` run and are replaced wholesale, leave them). Acceptance: RideTests `DiagnosticStoreTests` on an extracted pure `DiagnosticStore` (insert, replace-for-path, remove-path, ordered snapshot).

**6b Header-triggered recheck and whole-project check (Tier B).** Engine: `src/check/compile_db.rs` already lists sources; add `sources_including(header) -> Vec<PathBuf>` using `src/engine/include_graph.rs`; `run_check_c_project(root)` runs `clang -fsyntax-only` over every compile-database entry with a bounded worker pool (4) and returns one `CheckResult`. App: on save of a `.h`/`.hpp`, recheck the sources that include it; ⇧⌘B runs the project check with a progress line in the status bar. Acceptance: `tests/clang_check.rs`: editing `samples/cpp-demo/include/geo.h` to introduce an error yields a diagnostic attributed to `src/geo.cpp`; the project check on `samples/cpp-demo` returns zero diagnostics on the clean tree.

### 1.1-7 CMake and TOML cheat sheets (Tier A, one PR each)

**Read first.** `cheatsheets/rust/async.toml` (format), `src/cheatsheet/sheets/{mod,make}.rs` (how a language embeds its sheets), `src/cheatsheet/load.rs`, `src/highlight/context/{mod,make}.rs` (caret contexts), `tests/cheatsheet.rs`.

**Design.** `cheatsheets/cmake/*.toml`: `project`, `targets`, `variables-and-options`, `find-and-link`, `control-flow`, `functions-and-macros`, `install-and-test`. `cheatsheets/toml/*.toml`: `cargo-package`, `cargo-dependencies`, `cargo-features-and-profiles`, `cargo-workspace`, `toml-syntax`. Contexts: CMake gets `statement` (top level or inside a block) and `argument` (inside a command's parentheses); TOML gets `table` (on a blank line or `[`) and `key` (inside a table). Add `src/highlight/context/cmake.rs` and `toml.rs` on the `scan.rs` pattern. Separately: add `case` and `default` as Rust `match`-arm and C `switch`-body contexts to the existing C and Rust context scanners so the `switch`/`match` entries surface there.

**Acceptance.** `tests/cheatsheet.rs`: each new sheet loads with no duplicate `name` and every `snippet` parses (existing checks); a CMake caret inside `target_link_libraries(` returns the `find-and-link` entries first; a TOML caret under `[dependencies]` returns the dependency entries; a C caret inside `switch (x) {` returns `case` and `default`.

### 1.1-8 CI gates (Tier A, one PR each)

**8a Ranking goldens.** `tests/ranking.rs` exists; add `tests/goldens/<site>.txt` files (one per completion site kind) recording the top five hit names for a fixed caret in `samples/c-demo`, `samples/cpp-demo` and the demo crate; a test compares and prints a diff on mismatch; `RIDE_UPDATE_GOLDENS=1` rewrites them. Acceptance: goldens committed, test green, one deliberate ranking change fails it locally.

**8b Self-test in CI.** The scene is launched as `Ride --demo selftest --file <path> --report <path>` (flags in `app/Ride/Debug/DemoLaunch.swift`); it writes one `PASS`/`FAIL` line per step to the report and always exits 0 (`DemoSelfTest.finish`). Change `finish()` to call `exit(1)` when any line starts with `FAIL`, keep `NSApp.terminate` for the clean case. Add a `selftest` job to `.github/workflows/engine.yml` after `app`: launch the Debug build's binary from `target/xcode/Build/Products/Debug/Ride.app/Contents/MacOS/Ride` twice, once with `--file samples/cpp-demo/src/geo.cpp` and once with a file in the demo crate, each with `--report target/selftest-<n>.txt`, `cat` the reports into the log, and fail on a non-zero exit or on `grep -q '^FAIL'`. Acceptance: CI green; forcing one step to fail locally turns the job red.

### 1.1-9 Quick Documentation

**9a Engine: full doc block (Tier A).** **Read first:** `src/extract/docs.rs` (`preceding_docs`, `first_paragraph`), `src/highlight/c_docs.rs`, `src/engine/symbols.rs` (`find_definitions`, how a hit carries `source_path` and byte offsets), `src/markdown/html.rs` (`render`), `src/engine/tools.rs` (`render_markdown`), `tests/outline_docs.rs`.

Design: new `src/engine/docs.rs` with `Engine::quick_doc(session_id, cursor_byte) -> Option<QuickDoc>` where `QuickDoc { title, signature, html, origin_path, origin_line, links: Vec<DocLink> }`. Steps: resolve the symbol with the same lookup `find_definitions` uses; take the first hit; read its source (the buffer if `source_path` is the session's path, else the file at `source_path`); parse just enough to find the item node at the stored byte and lift the **whole** preceding doc block (`///`, `//!` for the enclosing module, `/** */`, Doxygen `@brief`/`@param` converted to a definition list). Rewrite intra-doc links (`` [`Type::method`] ``, `[text](Type::method)`) to `ride-doc://<path>` after resolving them through the catalog, leave unresolved ones as plain code. Render with `crate::markdown::render`. Nothing is added to the index. Extract a `doc_block.rs` (lifting) and `doc_links.rs` (rewriting) so `docs.rs` stays orchestration. Acceptance: `tests/outline_docs.rs` gains cases: multi-paragraph Rust doc with a fenced example renders `<pre>` with token spans; Doxygen block yields the brief as the first paragraph and params as a list; a link to `Counter::new` in the same buffer resolves to a `ride-doc://` URL; a link to an unknown item stays inline code.

**9b App: doc popup (Tier B, after 9a and the engine rebuild).** **Read first:** `Editor/HoverPanel.swift`, `HoverController.swift`, `Preview/MarkdownPreview.swift` (the existing `WKWebView` and `PreviewTemplate` theming), `Completion/CompletionDocCard.swift`, `Menus/ViewCommands.swift`.

Design: `Editor/DocPanel.swift` (an `NSPanel` hosting a `WKWebView` themed through `PreviewTemplate`, resizable, with a pin button that stops auto-hide; `ride-doc://` navigations call back into the controller to load that item), `Editor/DocController.swift` (⌃J and F1 fetch `quick_doc` at the caret; hover keeps `HoverPanel` and upgrades to `DocPanel` on ⌃J or click; ⌘I in the completion popup fetches for the selected hit by its definition), ⇧F1 opens `https://docs.rs/<crate>/latest/<crate>/?search=<name>` for catalog items or `https://en.cppreference.com/w/?search=<name>` for `std::` names. Menu items go through `MenuModel`. Acceptance: self-test steps: ⌃J on `Counter` shows a panel whose HTML contains `<h1>` text from the doc; ⌘I from a completion row shows the same; pinning keeps it across a caret move. The panel is single-instance per pane (see 1.1-1a).

### 1.1-10 Quick Definition (Tier B, after 1.1-9b)

**Read first.** 9a/9b PRs, `src/engine/symbols.rs`, `src/highlight/spans.rs` (`source_highlights`), `Editor/Definitions.swift`.

**Design.** Engine: `Engine::quick_definition(session_id, cursor_byte) -> Vec<DefinitionExcerpt>`: for each hit of `find_definitions`, the item's source from its signature start to the end of its body, capped at 60 lines with a `truncated` flag, plus highlight spans for the excerpt and `path`, `line`. App: `Editor/PeekPanel.swift` reuses `DocPanel`'s frame, pin and resize but renders an `NSTextView` with the spans applied through `HighlightApply`; header shows `path:line` and an Open button (F12 also works while it is up); when more than one excerpt is returned a segmented control switches between them (`declaration` / `definition`, or `trait` / `impl for X`). ⌘-hover stays the one-line signature. **Acceptance.** `tests/definition.rs`: excerpt for a C prototype and its definition returns two entries in that order; a Rust trait method with two impls returns three; a 200-line function is truncated at 60 with the flag. Self-test: ⌥Space on `record` in the demo crate shows a panel with two segments.

**Exit for 1.1.** As in `next.md`: two panes with independent popups; workspace reopens as left; update check installs a signed build; CI runs engine, app, goldens and self-test.

---

## 3. Release 1.2 — Build, run, test, debug

Settled design only; the rest is written when 1.1 ships.

### 1.2-1 Project model (Tier B, one PR per project kind)

- `src/project/mod.rs` with `ProjectModel { root, kind, targets: Vec<Target>, profiles: Vec<Profile> }`, `Target { name, kind: Bin|Lib|Test|Bench|Example|Custom, build_cmd, run_cmd, sources }`, and a `Detect` trait implemented by `cargo.rs`, `cmake.rs`, `make.rs`, `compile_db.rs`. Detection order is fixed in that order; first match wins.
- **Cargo** (`cargo.rs`): reuse `src/discover/metadata.rs`; targets from `cargo metadata` packages, features listed. Tier A.
- **CMake** (`cmake.rs`): write the File API query (`.cmake/api/v1/query/client-ride/query.json` asking for `codemodel-v2`), run `cmake -S root -B build/<profile> -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_BUILD_TYPE=<profile>`, read `reply/index-*.json` then the codemodel targets. The compile database the checker already uses is then `build/<profile>/compile_commands.json`; point `src/check/compile_db.rs` at it. Tier B. Tests on `samples/cpp-demo/CMakeLists.txt`, skipped when `cmake` is absent.
- **Makefile** (`make.rs`): targets from the make outline (`src/highlight/make_outline.rs`); `make -n <target>` to learn commands. Tier A.
- **Compilation database only** (`compile_db.rs`): each source is a target; build command is a user string stored with the workspace. Tier A.
- App: `app/Ride/Project/` Targets panel bound to the model; manifest watcher (`Workspace/CargoWatch.swift` generalised to `ManifestWatch`) reloads.

### 1.2-2 Run configurations (Tier B)

`app/Ride/Run/RunConfig.swift` (`Codable`, pure, in RideTests): target name, args, env, cwd, `RUST_BACKTRACE`, sanitizer set; the sanitizer flags mapping is a pure function per project kind (`RunConfig+Sanitizers.swift`, tested). Stored in the 1.1-2 workspace state file. Toolbar picker publishes through `MenuModel`. Shortcuts as in `next.md`.

### 1.2-3 Terminal and Run console (Tier B)

SwiftTerm as a Swift package. `app/Ride/Terminal/TerminalTab.swift` (pty over `/bin/zsh -l`), `RunConsole.swift` (same view fed by a `Process` pipe, `path:line:col` detection through a pure `ConsoleLinks.swift` regex in RideTests, Stop and Rerun). Build errors flow into the Problems panel through the existing `src/check/parse.rs` and `clang_parse.rs`; the engine gains `parse_build_output(kind, text) -> Vec<Diagnostic>` so the parsers stay in Rust. Tier A for the parsers and links; B for the pty and panel.

### 1.2-4 Test runner

**4a Parsers (Tier A).** `src/run/tests/{cargo,gtest,catch2,ctest}.rs`: list and result parsing from fixed fixtures in `tests/fixtures/run/`; a common `TestEvent` enum. **4b Runner and panel (Tier B).** Gutter ▶ from outline items (`#[test]`, `TEST(`, `TEST_CASE(`, `fn main`), Tests panel tree, rerun failed, filter.

### 1.2-5 Single-file run (Tier A)

`src/run/single.rs`: `clang`/`clang++`/`rustc` into a temp dir under the support directory, return the binary path and compiler diagnostics; Recompile File uses the compile-database command for that file. Tests on `samples/`.

### 1.2-6 Debugger (Tier C)

`lldb-dap` DAP client in `src/debug/` (protocol, transport, request/response types) and the app panels. The DAP message types and JSON round-trips are Tier A cards once the client shape exists; the session state machine and the UI stay on the strong model.

---

## 4. Releases 1.3 and 2.0 — tier assignments only

| Item | Tier | Why |
|---|---|---|
| 1.3-1 Reference index | C | New Tantivy schema, incremental rebuild, ranking; the per-language use extractors (`src/extract/refs/{rust,c}.rs`) become Tier A cards afterwards |
| 1.3-2 Rename | B | Buffer-local through existing scopes is A; workspace-wide depends on 1.3-1 and the preview sheet |
| 1.3-3 Generate | A per generator | Each generator (constructor, getters, `operator==`, `impl Default`, …) is one pure function over the `TypeTable` with a fixture test |
| 1.3-4 Refactor menu | C | Extract Function and Change Signature need data-flow decisions; Introduce Constant and Inline may be A afterwards |
| 1.3-5 Live diagnostics | A | Debounce, temp target dir, clang-tidy invocation; parsers exist |
| 1.3-6 Intentions | B | One menu over several sources; each fix is A |
| 1.3-7 Semantic highlighting, inlays, Type Info | C | Resolver quality decides the feature; hints stay off until 80% resolve |
| 1.3-8 Hierarchies | B | Queries over 1.3-1 and the `TypeTable`, plus a side panel |
| 2.0 diff engine | C | Shared by 2.0-1 and 2.0-4; pick Myers with line hashing, then the rest is B |
| 2.0-1/2/3 Git | B | `git` CLI wrappers are A (`src/git/` with fixture repos in a temp dir); panels B |
| 2.0-4 Local History | A | Snapshot per save, five-day sweep, list and diff |

---

## 5. Order of delegation

Start the executor on cards that are independent of 1.1-1a so the strong model can do the registry in parallel:

1. 1.1-7 (sheets), 1.1-5 (headers), 1.1-8a (goldens), 1.1-3a (universal build) — no shared state, fast review.
2. 1.1-4 a, b, c, f, g, 1.1-6a, 1.1-2 — app-side, each with a RideTests file.
3. 1.1-9a (engine docs) while 1.1-1a lands.
4. After 1.1-1a: 1.1-1b, 1.1-9b, 1.1-10, 1.1-4 d/h/i, 1.1-6b, 1.1-8b, 1.1-3b.

Review checklist for every hand-back: gates pasted; no comments in source; no file grew past ~200 lines; RideTests Sources phase updated for new pure files; no `.commands` block reads `AppState`; no `unwrap` outside `tests/`; the card's "out of scope" list was respected.
