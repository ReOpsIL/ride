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
- An executor worktree builds its own `target/` (several GB with the release engine build and Xcode derived data). After the card's commit, run `rm -rf target` in the worktree; the strong model removes merged worktrees with `git worktree remove --force`. On 2026-09-12 thirteen live worktrees filled the disk and stopped every tool.

### 1.3 Gates (all must pass before a card is "done")

```
cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
cargo test
bash scripts/build-engine.sh                      # only when src/ffi or src/engine changed
xcodebuild -downloadComponent MetalToolchain   # once per machine, needed by SwiftTerm's shaders
xcodebuild -project app/Ride.xcodeproj -scheme Ride -configuration Debug \
  -derivedDataPath target/xcode -destination 'platform=macOS,arch=arm64' \
  -skipPackagePluginValidation -skipMacroValidation \
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

**8b Self-test in CI.** The scene is launched as `Ride --demo selftest --open <crate> --report <path>` (flags in `app/Ride/Debug/DemoLaunch.swift` and `AppState+Launch.swift`); it writes one `PASS`/`FAIL` line per step to the report and always exits 0 (`DemoSelfTest.finish`). The crate is `samples/rust-demo`; the scene saves its edits, so every run must use a fresh copy (`cp -R samples/rust-demo "$TMPDIR/demo"`). Change `finish()` to call `exit(1)` when any line starts with `FAIL`, keep `NSApp.terminate` for the clean case. Add a `selftest` job to `.github/workflows/engine.yml` after `app`: launch the Debug build's binary from `target/xcode/Build/Products/Debug/Ride.app/Contents/MacOS/Ride` on a copy of `samples/rust-demo` and on a copy of `samples/cpp-demo` with `--file src/geo.cpp`, each with `--report target/selftest-<n>.txt`, `cat` the reports into the log, and fail on a non-zero exit or on `grep -q '^FAIL'`. Acceptance: CI green; forcing one step to fail locally turns the job red.

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

---

## 6. Review fixes after batches 1 and 2 (2026-09-11)

Reviews of the thirteen executor commits found the bugs below. Each is one card and one commit, same contract as section 1. Everything not listed was accepted.

### R1 System include detection through the engine (1.1-5) — Tier A

`app/Ride/Editor/BufferLanguage.swift` `isSystemInclude` hardcodes path fragments and every caller passes no directories, so the engine's `SystemIncludes` cache (`src/engine/sessions.rs`) is never consulted. Add `Engine::is_system_path(path: String) -> bool` in `src/engine/sessions.rs` (or a new `system_paths.rs`) backed by that cache, expose it through `src/ffi`, rebuild the engine, and make `BufferLanguage.isReadOnly` and the language sniff call it; delete the hardcoded fragment list. Test in `tests/system_headers.rs`. Also fix `opening_libcxx_vector_is_cpp_with_class_outline`: the libc++ `vector` file is a wrapper include, so assert `Lang::Cpp` on it and assert the `class vector` outline on `<sysroot>/c++/v1/__vector/vector.h` when that file exists, skip otherwise; drop the synthetic snippet.

### R2 Replace in Project safety (1.1-4f) — Tier B

`app/Ride/Search/ProjectReplaceApply.swift`: `writeBuffer` swallows a failed save and reports success while the buffer stays mutated; hits for closed files are applied from the preview-time snapshot. Fix: apply computes each closed file's edits from the file's current contents at apply time, skips a file whose text no longer contains the match and lists it in the result; a failed save leaves the buffer untouched (apply the edit only after a successful write, or revert on failure) and the summary names the files that failed. Extend `ProjectReplaceTests` with a changed-on-disk file being skipped.

### R3 Header-attributed diagnostics are never cleared (1.1-6a) — Tier B

`app/Ride/Engine/CheckService.swift` `ingestClang` replaces only the paths present in the new result, so a diagnostic once attributed to a header stays after the including source is rechecked clean. Fix: `DiagnosticStore` records which source file's check produced each path's C diagnostics; a recheck of source A first drops every path owned by A, then inserts the new ones. Cover it in `DiagnosticStoreTests`.

### R4 Empty workspace snapshot after open (1.1-2) — Tier B

`app/Ride/AppState.swift` `open(_:)` clears `buffers` and `activeID` after `workspaceRoot` already points at the new root; each clear schedules a save, and `restoringWorkspace` then suppresses the saves that would replace it, so 500 ms after opening a workspace the restored tabs are overwritten with an empty snapshot. Fix in `AppState+Workspace.swift`: cancel the pending save work item when the root changes, never schedule while `restoringWorkspace` is set, and schedule one save when restore finishes. Add a test on the pure part if any; otherwise a self-test step: open, restore, wait 1 s, read the state file and assert the tab list is not empty.

### R5 Rust doc block adjacency and HTML shape (1.1-9a) — Tier A

`src/engine/doc_comment.rs` `preceding` merges a doc comment separated by a blank line from the item; the C path's `adjacent` already refuses that. Share the adjacency rule between both paths. `src/engine/docs.rs` `wrap` concatenates an `<h1>` around the rendered body; instead `QuickDoc.html` is exactly `crate::markdown::render(body)` and the title stays in `QuickDoc.title` for the app to render. Add tests in `tests/outline_docs.rs` for the blank-line boundary and for `//!` module docs.

### R6 CI asserts the universal slice (1.1-3a) — Tier A

`.github/workflows/engine.yml` `xcframework` job: after `build-engine.sh`, run `lipo -info` on the static library inside `app/RideEngine.xcframework` and fail unless the output contains both `x86_64` and `arm64`.

### R7 Workspace restore loses the caret (1.1-2) — Tier B

`Ride --demo selftest --open <copy of samples/rust-demo>` fails its last step, `workspace restore`: after `captureWorkspace()` and `restoreWorkspace()` on the same state the caret sits on line 20 instead of the captured line 10 (reproduced on commit 79726a8, before the pane registry). Trace the caret from `BufferDocument.capture` through `TabState`, `buffer(from:)` and `BufferDocument.bind` into the new editor host, find which later step moves it (session attach, fold restore, highlight apply or scroll restore are the candidates) and fix that root cause, not the test. Acceptance: the self-test scene reports 52 PASS and 0 FAIL on a fresh copy of the crate.

## 8. Review fixes after batches 3, 4 and 5 (2026-09-11)

R1–R7 and cards 1.1-4d, 1.1-4e, 1.1-4i passed review. The rest need the fixes below; same contract, one card per commit.

### R8 Cheat sheet insert must push onto the snippet stack (1.1-4h) — Tier A

`app/Ride/CheatSheet/CheatSheetController.swift` `insert` still calls `SnippetInsert.insert` and assigns `session.snippet`, so a cheat-sheet insert inside a placeholder discards the outer stops. Route it through `CompletionSession.insertSnippet` (the push path from `CompletionSession+Snippet.swift`); `hide()` must not clear the stack. Add a `SnippetStackTests` case for push-from-cheat-sheet through the same API.

### R9 Deterministic project check output (1.1-6b) — Tier A

`src/check/clang_project.rs` `Merge` appends diagnostics and stderr in worker receive order. Tag each job with its compile-database index, collect into a `BTreeMap<usize, _>` and emit in index order; a test with a shuffled fake job order asserts the same output twice.

### R10 Sparkle embedding and placeholder key guard (1.1-3b) — Tier B

Two defects in `fac57d6`. (1) Sparkle is linked but no embed phase copies `Sparkle.framework` into `Ride.app/Contents/Frameworks`; add the `PBXCopyFilesBuildPhase` (destination frameworks, code sign on copy) in `app/Ride.xcodeproj/project.pbxproj` and confirm the Debug app launches (`otool -L` shows `@rpath/Sparkle.framework` and `--demo selftest` runs). (2) `Info.plist` ships the all-zero `SUPublicEDKey`; `UpdateController` must not start `SPUStandardUpdaterController`, and `RideApp` must not show "Check for Updates…", unless the key differs from the placeholder (`UpdateController.isConfigured`, a pure check in RideTests). `scripts/release.sh` exits non-zero when `RIDE_SPARKLE_PRIVATE_KEY_FILE` is set but `RIDE_SPARKLE_PUBLIC_KEY` is not.

### R11 One buffer per pane and per-pane restore (1.1-1b) — Tier B

A `BufferDocument` bound to two `EditorHostView`s does not sync (`EditorCoordinator.textDidChange` writes `document.text` from whichever view typed last), so showing one buffer in both panes loses edits. Until the panes share one `NSTextContentStorage` (recorded in `todo/app/remaining.md`), a buffer lives in exactly one pane: `PaneLayout.open(_:in:)` removes the tab from every other pane (`move` semantics, update `PaneLayoutTests`), `openSplit` creates an empty pane and focuses it (the pane column shows `WelcomeView`), `openInSplit` moves the buffer, and F10 moves the sibling. `SplitState` stores `panes: [[path]]`, `focused: Int` and `ratio`; `captureWorkspace` and `restoreWorkspace` round-trip it (test in `WorkspaceStateTests`). Also: `closeSplit` and `paneFocused` make the surviving pane's text view first responder; `TabStrip.onDrop` returns `false` for a payload that is not a tab id; one "Switch Header / Source" menu row.

### R12 Doc popup leaks, focus and content policy (1.1-9b) — Tier B

`app/Ride/Editor/DocWebView.swift`: the `WKScriptMessageHandler` registration retains the view (cycle through the configuration); register a weak proxy object instead and assert in a RideTests-free way that `deinit` runs (a `weak` reference test in the app target's self-test step is acceptable). `RideTextView+Keys.swift` `cancelOperation` and `PeekController.present` use the lazy `docs` accessor to test visibility and so construct a panel and web view on every Escape; use the nil-checking storage. `AppState+Panes.swift` `paneFocused` hides the previous pane's doc and peek panels unless pinned. `DocWebView` loads with a base URL and a `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:">` in `PreviewTemplate.popup`. Remove the dead `toggleWideDoc`/`wideDoc` code in `CompletionPopup.swift`. Make the `completion doc trigger` and `completion doc` self-test steps pass on a copy of `samples/rust-demo` (they fail today: `completion false hit nil`, `visible false`) (place the caret where a `Counter` hit exists, or open the completion on `Cou`); the scene must end with 0 FAIL and always write its report.

### R13 Demo fixture: a real trait and impl for `record` (1.1-10) — Tier A

`samples/rust-demo/src/util.rs` gained a dangling `Recorder` trait so `record` has two hits. Make it real: `pub trait Recorder { fn record(&mut self, name: &str); }` with `impl Recorder for Counter` holding the body, no inherent `record`; `src/main.rs` line 5 becomes `use util::{Counter, Recorder};` so the line count and every self-test line number stay the same. The `quick definition` self-test step fails today (`visible false labels []`); make it pass on a copy of the crate and confirm two segments.

### R14 C++ self-test steps (1.1-8b) — Tier B

`SelfTestSteps` is Rust-only, so the CI job cannot run `samples/cpp-demo`. Split it into `SelfTestSteps` (language-neutral: setup, indent, undo, duplicate, move line, go to line, back/forward, zoom, workspace) plus `SelfTestSteps+Rust.swift` and `SelfTestSteps+Cpp.swift`, chosen by the opened buffer's language. The C++ set on `samples/cpp-demo/src/shapes.cpp`: `//` comment toggle, matching brace, header/source switch to `include/shapes.hpp`, Complete Statement adding `;`, fold, Quick Definition on a method declared in the header. Add the second run to the `selftest` CI job on a fresh copy of `samples/cpp-demo`. Acceptance: both runs 0 FAIL.

### R15 Window restoration must not decide whether Ride opens (self-test hang) — Tier B

Ride opened no window at all on the maintainer's machine after the batch runs: macOS state restoration replayed a record left by a killed or `exit(1)`-terminated Ride, and SwiftUI restored "no windows". Launching with `-ApplePersistenceIgnoreState YES` opens normally; a clean quit repairs the record. Ride restores its own workspace (1.1-2), so macOS restoration is redundant: `WindowConfigurator` (RootView.swift) sets `window.isRestorable = false` on the main window, and every `NSPanel` (`OverlayPanel.make`, `DocPanel`, `PeekPanel`, `ShortcutsPanel`) sets `isRestorable = false`. `DemoSelfTest.finish` never calls `exit`; it writes the report, appends a final `EXIT 0` or `EXIT 1` line, and terminates normally. The CI job (1.1-8b) greps `^FAIL` and the `EXIT` line instead of the process status and passes `-ApplePersistenceIgnoreState YES` on every launch. Observed on 2026-09-11: launches with the record present opened no window (RootView `onAppear` never fired, main thread idle); `defaults write dev.ride.Ride NSQuitAlwaysKeepsWindows -bool false` did not help, `-ApplePersistenceIgnoreState YES` (also as a per-app default) did. The maintainer's machine currently has that default set; the code fix must work with the default deleted. Acceptance: with `defaults delete dev.ride.Ride ApplePersistenceIgnoreState`, the scene runs to completion twice in a row with a `kill -9` of an unrelated plain launch in between.

### R16 Doc popup leftovers and catalog hit offsets (R12, R11) — Tier A

Three leftovers from batch 6. (1) `CompletionPopupLayout.wide` and `CompletionDocCard.wideWidth` are now permanently false/unused after the wide-doc toggle was removed; delete the state and the layout branch. (2) `DocWebView.swift` builds its base URL with a force-unwrap; use a static `URL` built through a failable path that falls back to `about:blank` without `!`. (3) `SessionService+Query.swift` relocates the doc cursor by searching the hit's name after `byteStart` because catalog hits point at the item start (`pub struct`), not the name; fix the engine instead: `CompletionHit` gains `name_byte: Option<u32>` filled by `src/engine/symbols.rs` and `query` hits from the outline's name span (`OutlineItem` already carries `start_byte`; add `name_start_byte` in `src/highlight/symbol.rs` and the extract path), `quick_doc` and `quick_definition` accept either byte, and the Swift search fallback is deleted. Test in `tests/definition.rs`: a catalog hit's `name_byte` lands on the identifier. Also `SplitState.tabs(ids:leftover:)` in `WorkspaceState.swift` dedupes a path listed in two saved panes (first pane wins) with a `WorkspaceStateTests` case.

### R17 Demo launches still open no window without the persistence flag (R15) — Tier B

R15's delegate refusal and `isRestorable = false` did not meet its acceptance. Verified on 2026-09-11 with `defaults delete dev.ride.Ride ApplePersistenceIgnoreState`: a plain `Ride --open <crate>` launch opens a window, but `Ride --demo selftest --open <copy> --report <file>` opens none, writes no report and never terminates (RootView `onAppear` never runs; main thread idle). The same command with `-ApplePersistenceIgnoreState YES` passes 60/60. Fix so the flag is unnecessary: in `RideApp.init`, before anything else, `UserDefaults.standard.register(defaults: ["ApplePersistenceIgnoreState": true])` and also `set(true, forKey:)` so AppKit sees it from the first launch on; keep R15's delegate and `isRestorable` changes. Then find why the demo path differs from the plain path (the only differences are `DemoLaunch.isDemo` gating `restoreOpenedWorkspace`/`canPersistWorkspace` and `DemoLaunch.start` in `RootView.onAppear`): instrument with `FileHandle.standardError` prints during the investigation and remove them before the hand-back. Acceptance, run by hand and pasted: `defaults delete dev.ride.Ride ApplePersistenceIgnoreState`, then the self-test scene on a fresh copy of `samples/rust-demo` WITHOUT the flag completes twice in a row with `EXIT 0`, and a plain launch in between still opens a window. Re-run the CI job definition locally (`.github/workflows/engine.yml` selftest steps) to confirm it still passes.

### R18 Targets panel leftovers (P5) — Tier B, after Q1

Four findings on commit 2e15771. (1) `app/Ride/Workspace/ManifestWatch.swift` ignores every path under `build/`, so `build/compile_commands.json`, a location the detector supports, never triggers a reload; ignore only `target/` and `build/<subdir>/…` (depth two and deeper, which is where cmake configures), and watch `build/compile_commands.json` itself. (2) `closeWorkspace` in `Buffers+File.swift` never clears `ProjectModelStore`, so the Targets panel keeps the previous workspace's targets; clear it there. (3) The selected target is never restored: on `restoreWorkspace` apply `WorkspaceState.selectedTarget` (the field Q1 adds) to the store, and write it on every selection. (4) `src/project/compile_db.rs` duplicates the entry struct and the command/arguments split from `src/check/compile_db.rs` and adds the `shell-words` crate although `shlex` is already a dependency; extract one shared `src/check/compile_db/entry.rs` (or similar) used by both and drop `shell-words` from `Cargo.toml`. Also consolidate `CargoWatch` into `ManifestWatch` so one watcher decides both the cargo reindex and the project reload; keep the existing `CargoWatchTests` cases by pointing them at the consolidated pure function. Acceptance: RideTests for the watcher filter (build/compile_commands.json fires, build/Debug/compile_commands.json does not), `tests/project_compile_db.rs` unchanged and green, a self-test step that selects a target, captures and restores the workspace, and asserts the selection.

### R19 Run output leftovers (Q2) — Tier B, after Q3

Three defects on commit f7b3484. (1) `ProcessRunner.receive` decodes each pipe chunk on its own, so a multi-byte UTF-8 character split across two reads becomes U+FFFD; keep a byte buffer, decode only up to the last complete line, and carry the remainder (RideTests on a pure `LineSplitter.swift` with a chunk boundary inside a 3-byte character). (2) Once `RunOutput.lines` reaches `maxLines` and rolls, `RunOutputText`'s `rendered` count never falls below `lines.count`, so the view stops appending; track a monotonically increasing line sequence number instead of the array count, drop from the text storage what the model dropped, and replace `removeFirst` with a ring or a chunked drop so the cap is O(1) per line. (3) Nothing stops a running process on workspace switch or close: `open(_:)`, `closeWorkspace` and `watchWorkspaceQuit` call `runOutput.stop()` first. Also narrow `ConsoleLinks` so `host:port` forms with a dotted host (`example.com:8080`) are not links. Acceptance: RideTests for the splitter, the sequence-number append logic (pure part extracted) and the link filter; self-test step: a run of `["sh","-c","seq 1 7000"]` ends with the panel showing line 7000.

### R20 Build session lifecycle (Q4b) — Tier A, after Q5b

`BuildSession.finish()` runs on every run finish regardless of which run produced it and of how it ended: Stop (⌘.) during a build publishes the partial diagnostic set, and "Stop and rerun" lets the old process's finish land on the new session. Fix: `RunOutput` hands each run a monotonically increasing run id and passes it with the exit status to `onFinish`; `BuildSession.begin` records the id it belongs to; `finish` ignores any other id and any `.signalled`/stopped status (it leaves the previous diagnostics untouched); `stopRun` cancels the session explicitly. RideTests on the pure part (extract `BuildSessionState.swift`: begin/finish/cancel with ids and statuses). Self-test step: start a Build, stop it within 200 ms, assert no build diagnostics were published and the panel status says stopped.

### R21 Catch2 through the XML reporter, verified against a real binary (T1) — Tier A

`src/run/tests/catch2.rs` was written without a Catch2 binary: the compact reporter never prints passes without `-s`, and the parsed vocabulary (`passed:`/`for:`) does not match Catch2's real output. Replace it: `test_commands` for Catch2 runs the binary with `--reporter xml` (list stays `--list-tests`), and the parser reads the XML (`<TestCase name=… filename=… line=…>`, `<OverallResult success=…>`, `<Expression success=… filename=… line=…>` with `<Original>`/`<Expanded>`, `<Section>`), producing one event per test case with the failed expressions in `output`; use a small hand-rolled tag scanner or add `quick-xml` (pinned) to `Cargo.toml`. Verify against a real build: download the Catch2 v3 amalgamated `catch_amalgamated.hpp`/`.cpp` from the GitHub release into a temp dir, compile a ten-line program with one passing and one failing test, capture `--list-tests` and `--reporter xml` output into `tests/fixtures/tests/catch2-list.txt` and `catch2-run.xml`, and say in the hand-back which Catch2 version produced them. Also in `src/run/tests/cargo.rs`, key stdout blocks by (binary, name) using the `Running <path>` lines so two binaries sharing a test name keep their own output; add a fixture case.

### R22 Single-file run tests and compile flags from the database (Q5b) — Tier A, after R20

(1) `app/Ride/Run/SingleFileRun.swift` is FFI-free but not in the RideTests Sources phase and has no tests: register it and add `SingleFileRunTests` (supported extensions, output name is `single/<sha256>`, the chain releases only on exit 0 and clears on stop or on a different run id). (2) `single_file_command` builds a bare compiler line, so Run File on a project source that includes project headers fails at the include stage; when `compile_db::lookup` finds an entry for the file, reuse its `-I`, `-D`, `-std` and `-isystem` flags (only those, dropping `-c`, `-o` and the input), with a `tests/single.rs` case on a temp copy of `samples/cpp-demo` where Run File on `src/main.cpp` then fails at link (the acceptance the card originally described) and the self-test step asserts the linker error text.

### R23 Build output lines gated by run id (R20) — Tier A, after R22

`BuildSession.line` checks only `isActive`, so during a stop-and-rerun the dying process's trailing stdout (delivered until SIGKILL, up to 3 s) is accumulated into the new session. `ProcessRunner` and `RunOutput.append` carry the run id with every line; `BuildSession.line(runId:_:)` ignores lines whose id is not the session's; `RunOutput.finished` asserts the id it receives is the current run. `BuildSessionStateTests` gains a case where a line with the old id arrives after `begin` for the new id and is dropped; the self-test gains a stop-and-rerun step (start a build, immediately start another, wait, assert exactly one build's diagnostics and status).

## 9. Release 1.2 cards — project model (2026-09-11)

The 1.2-1 sketch in section 3 becomes five cards. The engine owns detection; the app only renders. Everything lives under `src/project/` (new module, listed in `src/lib.rs`), exposed through one `Engine::project_model(root: String) -> Result<ProjectModel, EngineError>` and re-read on `Engine::reload_project(root)`.

### P1 Project model types and detection order — Tier A

`src/project/model.rs`: UniFFI records `ProjectModel { root: String, kind: ProjectKind, targets: Vec<Target>, profiles: Vec<String>, manifest: String }`, `enum ProjectKind { Cargo, CMake, Make, CompileDb, None }`, `Target { name: String, kind: TargetKind, build: Vec<String>, run: Option<Vec<String>>, sources: Vec<String>, working_dir: String }`, `enum TargetKind { Bin, Lib, Test, Bench, Example, Custom }` (records in `src/ffi/project.rs`, re-exported from `src/ffi/mod.rs`). `src/project/mod.rs`: `trait Detect { fn detect(root: &Path, config: &EngineConfig) -> Result<Option<ProjectModel>, EngineError>; }` and `pub fn detect(root, config)` that tries Cargo, CMake, Make, CompileDb in that order and returns `ProjectKind::None` with no targets when nothing matches. `Engine::project_model` and `reload_project` in `src/engine/project.rs`, cached per root behind the existing engine lock. Tests in `tests/project.rs`: an empty temp dir yields `None`; detection order is asserted with a temp dir holding both `Cargo.toml` and `CMakeLists.txt`. Commands are argv vectors, never shell strings. Detectors for this card are stubs returning `Ok(None)`; the next cards fill them.

### P2 Cargo detector — Tier A

`src/project/cargo.rs`: reuse `src/discover/metadata.rs` (`cargo_metadata` JSON; extend the private `MetaPackage` with `targets: Vec<MetaTarget { name, kind: Vec<String>, src_path }>` and `features`) so workspace members produce targets: `bin` → `Bin` with `build = ["cargo","build","-p",pkg,"--bin",name]` and `run = ["cargo","run","-p",pkg,"--bin",name]`; `lib` → `Lib` (`cargo build -p pkg --lib`, no run); `test` and `#[cfg(test)]` units → one `Test` target per package (`cargo test -p pkg`); `bench` → `Bench`; `example` → `Example` (`cargo run -p pkg --example name`). Profiles `["debug","release"]`; `working_dir` is the workspace root; `manifest` is the root `Cargo.toml`. Tests on `tests/fixtures/sample_crate` and `samples/rust-demo` with `offline_metadata: true`: the demo yields one `Bin` named `ride-demo` and one `Test`.

### P3 Makefile detector — Tier A

`src/project/make.rs`: when `Makefile` or `GNUmakefile` exists at the root and no Cargo manifest, parse it with the tree-sitter make grammar through `src/highlight/make_outline.rs` to list rule targets; skip pattern rules (`%`), special targets (`.PHONY`, `.SUFFIXES`) and file targets whose name contains `/` unless they are the `all` prerequisite. Each remaining target becomes `Custom` with `build = ["make", name]`; `run` is `["make", "run"]` when a `run` target exists, else `None`; `sources` come from `make -n <target>` output lines that mention `.c`, `.cpp` or `.cc` files (bounded to 2 s with `-n` only, never executing recipes). Profiles: `["default"]`. Test on `samples/cpp-demo` (it has both `CMakeLists.txt` and a `Makefile`, so call the detector directly, not `detect`): targets contain `all`, `run`, `clean`, `compile_commands`, and `build/demo`'s sources include `src/main.cpp`.

### P4 CMake detector through the File API — Tier B

`src/project/cmake.rs`: when `CMakeLists.txt` exists at the root, write the File API query `build/<profile>/.cmake/api/v1/query/client-ride/query.json` (`{"requests":[{"kind":"codemodel","version":2}]}`), run `cmake -S <root> -B build/<profile> -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_BUILD_TYPE=<Profile>` for the requested profile (default `Debug`; profiles `["Debug","Release","RelWithDebInfo"]`), then read `reply/index-*.json` and the codemodel's target JSON files: `EXECUTABLE` → `Bin` with `build = ["cmake","--build","build/<profile>","--target",name]` and `run = ["build/<profile>/<artifact path>"]`, `STATIC_LIBRARY`/`SHARED_LIBRARY` → `Lib`, targets whose name starts with `test` or that CTest lists → `Test` (`["ctest","--test-dir","build/<profile>"]`), `UTILITY` → `Custom`. `sources` from the target's `sources` array. `manifest` is `CMakeLists.txt`. Point `src/check/compile_db.rs` lookups at `build/<profile>/compile_commands.json` when the root has a CMake model (so the checker uses the generated database). Never run cmake when `cmake` is not on PATH: return `Ok(None)` and record the reason in `ProjectModel.notice`, a new optional string added to the P1 record. Tests on `samples/cpp-demo` (skipped when `cmake` is absent): targets `demo` (Bin, sources include `src/main.cpp`) and `shapes` (Lib); the compile database path exists after detection.

### P5 Compilation-database-only detector and the app Targets panel — Tier B

`src/project/compile_db.rs`: when only `compile_commands.json` exists (root or `build/`), every source file is a `Custom` target with `build` equal to that entry's command split by `shell-words` (add the crate) and `working_dir` its `directory`; `run = None`. App: `app/Ride/Project/ProjectModelStore.swift` (fetches `project_model` on workspace open and on manifest change through `ManifestWatch`, a generalisation of `Workspace/CargoWatch.swift` that also watches `CMakeLists.txt` and `Makefile`), `Project/TargetsPanel.swift` (a sidebar section listing targets grouped by kind with the profile picker for CMake), `Project/TargetRows.swift` (pure row model in RideTests: grouping, sort, display names). Selecting a target publishes `MenuModel.selectedTarget`; nothing runs yet (1.2-2). Acceptance: RideTests `TargetRowsTests`; self-test step on `samples/rust-demo`: the store reports one `Bin` target after open.

## 10. Release 1.2 cards — run configurations and run output (2026-09-11)

1.2-2 and the console half of 1.2-3, ordered so every card ships something usable. SwiftTerm and the shell terminal stay in a later card; the run output view here is an `NSTextView` that 1.2-3 replaces.

### Q1 Run configuration model — Tier A

`app/Ride/Run/RunConfig.swift` (pure, RideTests): `struct RunConfig: Codable, Equatable { var target: String; var args: [String]; var env: [String: String]; var workingDir: String?; var rustBacktrace: Bool; var sanitizers: Set<Sanitizer> }`, `enum Sanitizer: String, Codable, CaseIterable { address, undefined, thread }`. `RunConfig+Sanitizers.swift` (pure): `func flags(for kind: ProjectKind) -> (env: [String: String], args: [String])` where Cargo gets `RUSTFLAGS=-Zsanitizer=<name>` plus `--target <host triple>` on nightly only (leave a `requiresNightly` flag the caller shows), and CMake gets `-DCMAKE_CXX_FLAGS=-fsanitize=<names>` at configure time. Because `ProjectKind` is an FFI enum, the pure file takes its own `enum RunProjectKind` mirror and `RunConfig+Engine.swift` (app target) maps between them. `WorkspaceState` gains `runConfigs: [RunConfig]` and `selectedTarget: String?` with defaults so older files decode. Tests: `RunConfigTests` (round trip, sanitizer flags per kind, default config for a target has no args and inherits the model's `working_dir`).

### Q2 Process runner and run output panel — Tier B

`app/Ride/Run/ProcessRunner.swift`: runs an argv vector with `Foundation.Process` in a working directory with a merged environment, streams stdout and stderr lines through a callback on the main queue, exposes `stop()` (SIGTERM, then SIGKILL after 3 s) and the exit status; one runner per workspace, a second run while one is active asks "Stop and rerun?". `app/Ride/Run/RunOutputPanel.swift`: a bottom panel tab next to Problems (`AppState.showRunOutput`, persisted in `LayoutState`) with a monospaced `NSTextView`, ANSI SGR colors reduced to the theme's eight colors through a pure `AnsiSpans.swift` (RideTests), a toolbar with Stop, Rerun and Clear, and `path:line:col` links detected by a pure `ConsoleLinks.swift` (RideTests: `src/main.rs:10:5`, `src/geo.cpp:12:3: error:`, absolute and relative paths) that open the file at the line through the focused pane. Menu items go through `MenuModel.isRunning`. Acceptance: `AnsiSpansTests`, `ConsoleLinksTests`; self-test step that runs `["echo","hello"]` through the runner and asserts the panel text.

### Q3 Run, Build and Test commands with the target picker — Tier B

`app/Ride/Run/RunCommands.swift` (`.commands`, MenuModel only): Build ⌘B, Run ⌘R, Run Tests ⇧⌘R, Stop ⌘. , Edit Configurations…; `AppToolbar` gets a target picker fed by `ProjectModelStore` (P5) that writes `WorkspaceState.selectedTarget`. `AppState+Run.swift`: resolves the selected target's `RunConfig` (or the default), builds the argv: Build uses `target.build`, Run uses `target.run` (disabled when nil), Run Tests uses the project's `Test` target (Cargo: `cargo test -p pkg`; CMake: `ctest --test-dir build/<profile>`; Make: `make test` when such a target exists) and appends the config's args, env, `RUST_BACKTRACE=1` when set, and the sanitizer flags from Q1. `RunConfigSheet.swift`: a sheet editing args, env (key/value table), working dir, backtrace and sanitizers for the selected target. Acceptance: RideTests `RunPlanTests` on a pure `RunPlan.swift` that turns (target, config, kind) into (argv, env, cwd); self-test steps on `samples/rust-demo`: Build runs `cargo build` to exit 0 and the panel shows `Finished`; Run shows `ride: 1`.

### Q4 Build diagnostics into Problems — Tier A

Builds started from Q3 run Cargo with `--message-format=json-diagnostic-rendered-ansi` and feed each JSON line to the existing `src/check/parse.rs` path through a new `Engine::parse_cargo_line(line) -> Vec<Diagnostic>`; the rendered text is what the panel shows. CMake and Make builds stream through `Engine::parse_clang_output(text) -> Vec<Diagnostic>` over `src/check/clang_parse.rs`. Diagnostics replace the previous build's set (a `build` owner in `DiagnosticStore`, distinct from the check owners), and the Problems panel shows them with a "build" badge. Tests: `tests/check.rs` cases for both parsers on captured output fixtures under `tests/fixtures/build/`; RideTests `DiagnosticStoreTests` for the build owner.

### Q5 Single-file run and Recompile File (1.2-5) — Tier A

`src/run/single.rs` (new `src/run/` module): `Engine::single_file_command(path) -> Result<SingleRun, EngineError>` returning `{ compile: Vec<String>, run: Vec<String>, output: String }` for `.c` (`clang`), `.cpp`/`.cc` (`clang++ -std=c++20`) and `.rs` (`rustc --edition 2021`) into `<support dir>/single/<hash>/` (the app passes the directory), using the toolchain lookup in `src/toolchain.rs`; `Engine::recompile_command(path) -> Option<Vec<String>>` from the compile database entry for that file. App: Run File (⌃⇧R) and Recompile File (⇧⌘F9) in Q3's menu; both go through the Q2 runner; compile errors go through Q4. Tests: `tests/single.rs` compiles and runs a temp `hello.c`, `hello.cpp` and `hello.rs` when the tools exist.

### Q4b Build diagnostics into Problems, app half — Tier B, after Q3

Engine first: `Engine::parse_clang_output(text, base_dir: String)` resolves relative diagnostic paths against `base_dir` before reading byte offsets (`src/check/clang_parse.rs` / `offsets.rs` take the base; the existing `run_check_c` passes the compile database entry's directory), with a `tests/build_output.rs` case using a relative path and a base. App: `DiagnosticStore` gains a `build` owner distinct from the check owners; a build started from Q3 streams its output through `parseCargoLine` (Cargo builds run with `--message-format=json-diagnostic-rendered-ansi`, the rendered text goes to the panel) or `parseClangOutput` with the build's working directory; the set replaces the previous build's diagnostics when the build ends; the Problems panel shows a "build" badge on those rows. RideTests `DiagnosticStoreTests` for the build owner; self-test step: a build of `samples/rust-demo` after inserting a type error at line 13 shows one build diagnostic, and a clean rebuild clears it.

### Q5b Single-file run and Recompile File, app half — Tier A, after Q3

Engine first: `recompile_command` returns a `RecompileCommand { argv: Vec<String>, directory: String }` record (`src/ffi/run.rs`) so the runner has its working directory; update `tests/single.rs`. App: Run File (⌃⇧R) and Recompile File (⇧⌘F9) in the Run menu through `MenuModel`; Run File asks the engine for `single_file_command(path, <support dir>/single/<sha256 of path>)`, runs the compile argv through the Q2 runner in the file's directory, then the run argv; compile errors go through Q4b's clang parser with the file's directory as base. Recompile File runs the record's argv in its directory. Self-test steps on `samples/cpp-demo`: Run File on `src/main.cpp` fails to link alone (expected: the panel shows the linker error), Recompile File on `src/shapes.cpp` exits 0.

## 11. Release 1.2 cards — test runner and terminal (2026-09-12)

### T1 Test output parsers — Tier A

`src/run/tests/` with one parser per framework, all producing `TestEvent { suite: Option<String>, name: String, status: Passed|Failed|Ignored|Started, output: String, duration_ms: Option<u64> }` and `TestCase { suite, name, file: Option<String>, line: Option<u32> }` (records in `src/ffi/tests.rs`): `cargo.rs` parses the stable human output of `cargo test` (`test name ... ok|FAILED|ignored`, the `---- name stdout ----` blocks, and `test result:` lines; JSON output needs nightly and is out of scope) and lists tests from `cargo test -- --list` (`name: test` lines); `gtest.rs` parses `--gtest_list_tests` (suite lines ending in `.`, indented case names) and the `[ RUN ]`/`[ OK ]`/`[ FAILED ]` result lines with the output between them; `catch2.rs` parses `--list-tests` and the `-r compact` reporter; `ctest.rs` parses `ctest --show-only=json-v1` and `ctest --output-on-failure` results. `Engine::list_tests(kind, text)` and `Engine::parse_test_output(kind, text) -> Vec<TestEvent>` over a `TestFramework` enum; the commands to produce the text come from a pure `test_commands(target, framework) -> (list: Vec<String>, run: Vec<String>)`. Fixtures under `tests/fixtures/tests/` captured from real runs (the demo crate for cargo; write a ten-line GoogleTest and Catch2 program each, build them only if the frameworks are installed, otherwise commit the captured output text); tests in `tests/test_output.rs`.

### T2 Gutter run markers and the Tests panel — Tier B, after T1 and Q4b

Engine: `Engine::test_markers(session_id) -> Vec<TestMarker { name, byte_start, framework }>` from the outline: Rust `#[test]` functions and `fn main`, C++ `TEST(` / `TEST_F(` / `TEST_CASE(` calls (tree-sitter call expressions at file scope). App: `GutterView` draws ▶ on marker lines and a click runs that test (`cargo test <name> -- --exact`, `--gtest_filter=Suite.Name`, `"<name>"` for Catch2) through the Q2 runner; `app/Ride/Tests/TestsPanel.swift` as a bottom panel tab next to Run Output with a pass/fail tree (`TestTree.swift`, pure, RideTests: grouping by suite, counts, filter), output per test on selection, Rerun Failed and a filter field; `Run Tests` (⇧⌘R from Q3) now streams through `parse_test_output` and fills the panel while the raw text still goes to the run output. Self-test steps on `samples/rust-demo` (add one `#[test]` in `util.rs` below the impl so line numbers in `main.rs` are untouched): Run Tests shows one passed test in the tree.

### S1 Terminal panel on SwiftTerm — Tier B

Add SwiftTerm as a Swift package (pin the latest 1.x); `app/Ride/Terminal/TerminalTab.swift` hosts `LocalProcessTerminalView` running the user's login shell (`SHELL` or `/bin/zsh -l`) with `cwd` = workspace root and the app's environment plus `TERM=xterm-256color`; `TerminalPanel.swift` is a bottom panel tab with multiple terminals (tab strip, New Terminal, close, ⌥F12 toggles the panel and focuses the terminal); Open in Terminal from the project tree opens a new tab in that directory; theme colors from `ThemeStore`; terminals are killed on workspace close and quit. The panel joins the bottom `VSplitView` with the same height persistence as Run Output. RideTests for the pure `TerminalTabs.swift` model (add, close, select fallback). Self-test step: open a terminal tab, assert the model has one tab; do not type into it.

## 7. Batch log

| Batch | Cards | Result |
|---|---|---|
| 1 | 1.1-7 ×2, 1.1-5, 1.1-8a, 1.1-3a | 5 commits, reviewed; R1, R6 |
| 2 | 1.1-4 a b c f g, 1.1-6a, 1.1-2, 1.1-9a | 8 commits, reviewed; R2–R5, R7 |
| strong model | 1.1-1a pane registry, `samples/rust-demo` fixture | commit on this branch; 141 RideTests, self-test 51/52 (R7 pre-existing) |
| 3+4 | R1–R7, 1.1-4 d e h i, 1.1-6b, 1.1-8b, 1.1-3b | 14 commits, reviewed; R8–R10, R14 |
| 5 | 1.1-1b, 1.1-9b, 1.1-10 | 3 commits, reviewed; R11–R13 |
| 6 | R8–R15 | 8 commits, reviewed; R16 |
| 7 | R17, R16, P1 | 3 commits, reviewed and merge-ready; gates green (183 app tests), self-test 65/65 Rust and 30/30 C++ without the persistence flag; the shared `name_start_byte` helper was deduplicated by the strong model |
| 9 | Q1, Q4, Q5 in parallel; then Q2; then R18 and Q3; then Q4b, Q5b | Q1–Q5 engine/model halves, Q2, Q3, R18, R19 merged and reviewed (244 app tests, self-test 72/72); Q4b merged, reviewed: R20; Q5b and S1 running |
| 10 | T1 merged, reviewed: R21 (Catch2 rework); S1 merged (SwiftTerm needs the Metal toolchain and the plugin-validation skip flags, now in the gate and CI); Q5b merged, reviewed: R22; gates green on 75bda62 (257 app tests, self-tests 77/77 and 32/32); R20 merged, reviewed: R23; R21 merged; R22 and T2 running; then R23 |
| 8 | P2–P4 in parallel, then P5 | P2–P4 merged and reviewed (gates green, 183 app tests, self-test 65/65); the strong model fixed the cmake-missing detection order. P5 in progress. Grok's balance ran out, so from here the executor is a Claude Opus subagent per card in its own git worktree (tests in per-card files such as `tests/project_cargo.rs` to avoid merge conflicts), merged into `grok/next-impl` by the strong model after review |

The Grok runner lives at `scripts/run-cards.sh` (unused since batch 7): one card name per argument, one commit per card, logs under `target/executor-logs/`.
