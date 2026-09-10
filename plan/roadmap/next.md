# Ride — Next features and roadmap (2026-09-10, revised after the RustRover pass)

| Field | Value |
|---|---|
| Baseline | 1.0 backlog done except A3 split, update check and universal build (`improve-extend.md`); completion phases 1–5 done (`completion.md`); cheat sheet shipped (`cheatsheet.md`); editor must-haves shipped (`must_have.md`) |
| Principle | Keep KD-1/2/6: Swift shell, Rust engine, no cloud model, no LSP dependency. Everything below runs locally and answers in milliseconds. |
| Reference | RustRover help: [quick start](https://www.jetbrains.com/help/rust/quick-start-guide-rustrover.html), [reference views](https://www.jetbrains.com/help/rust/viewing-reference-information.html), [inspections](https://www.jetbrains.com/help/rust/code-inspection.html), [refactoring](https://www.jetbrains.com/help/rust/refactoring-source-code.html), [terminal](https://www.jetbrains.com/help/rust/terminal-emulator.html), [local history](https://www.jetbrains.com/help/rust/local-history.html), [bookmarks](https://www.jetbrains.com/help/rust/bookmarks.html), [debugging](https://www.jetbrains.com/help/rust/debugging-code.html), [VCS](https://www.jetbrains.com/help/rust/version-control-integration.html) |
| Horizon | Four releases: 1.1 (trust), 1.2 (workbench), 1.3 (understanding code), 2.0 (working with code) |

## Second-pass audit against RustRover

The first draft covered the editor menus. Checked against the rest of RustRover, these are missing and now placed (or deliberately excluded):

| RustRover feature | Disposition |
|---|---|
| Find Action / Search Everywhere (⇧⌘A, double ⇧) | Added 1.1-11: command palette over every menu command, files and symbols |
| Quick Definition (⌥Space), External Documentation (⇧F1), breadcrumbs | Added 1.1-12, 1.1-13 |
| Terminal tool window (⌥F12), Open in Terminal | Added 1.2-1 (Ride opens Terminal.app today) |
| Bookmarks (F3 / ⌘F3 on mac, mnemonic 0–9), Bookmarks tool window | Added 1.2-2 |
| Local History with labels and revert | Added 1.2-3 |
| TODO tool window | Added 1.2-4 |
| Type Info (⌃⇧P), inlay hints incl. chained methods, parameter names | Added 1.3-5 (type info popup next to inlays) |
| Refactor menu: Extract Variable/Function, Inline, Introduce Constant, Change Signature, Safe Delete, Move | Added 1.3-9 |
| Intention actions (⌥↩) with red/yellow bulbs, inspections profile | 1.3-7 becomes the unified ⌥↩ menu; inspections limited to what tree-sitter and the compiler give |
| Clippy as external linter, run-on-save configuration | Added to 1.3-6 |
| Macro expansion (⌥↩, gutter) | 2.0-9, only when `cargo-expand` is installed |
| Cargo tool window: targets, features, commands; Cargo run configurations with env, args, backtrace; gutter run icons; doc tests; benches | 2.0-1 expanded |
| Debugger: conditional and panic breakpoints, watches, evaluate, attach, LLDB renderers | 2.0-2 expanded |
| VCS: commit window, diff, annotate, history, branches, shelve/stash, conflict resolution, gutter markers | 2.0-3 expanded |
| Rust Playground share | 2.0-10, opt-in and explicit |
| Coverage, profiler, database, services, endpoints, GitHub PR integration, remote development | Non-goals for 2.0 |

## What holds Ride back

1. **One buffer at a time.** No editor split, no side-by-side header/source (A3 blocked on the `EditorJump` singleton).
2. **No workbench around the editor.** No terminal, bookmarks, history, TODOs or command palette; every task outside typing leaves the app.
3. **Symbols are names, not references.** No find-usages, rename, refactorings or call hierarchy.
4. **Diagnostics are per save.** No live errors, no quick fixes, no Clippy, no whole-project C check.
5. **Trust and distribution.** No update check, no crash reporting, no universal build, no integration test in CI.

## Release 1.1 — Trust (4–5 weeks)

Goal: a daily driver a Rust/C developer keeps open all day, and a release channel that reaches them.

| # | Feature | Design notes | Where | Days |
|---|---|---|---|---|
| 1.1-1 | **Editor split** (A3) | Replace the `EditorJump` singleton with a per-pane `EditorHost` registry keyed by pane id; `AppState` tracks the focused pane; open-in-split from the tree, ⌘\ to split, drag tabs between panes; Switch Header/Source opens the sibling in the other pane. | `app/Ride/Editor`, `AppState+Layout` | 5 |
| 1.1-2 | **Persistent workspace state** | Open tabs, split layout, caret and folds per file, panel sizes restored per workspace root (`~/Library/Application Support/Ride/workspaces/<hash>.json`). | `app/Ride/Workspace` | 2 |
| 1.1-3 | **Update check** | Sparkle with the appcast published by `scripts/release.sh`; Check for Updates menu item; no telemetry. | `scripts/`, `RideApp` | 2 |
| 1.1-4 | **Universal build** | x86_64 xcframework slice; CI matrix. | `scripts/build-engine.sh`, CI | 1 |
| 1.1-5 | **Cheat sheet follow-ups** | TOML and CMake sheets; `case`/`default` context; highlighted preview; pinned-mode debounce. | `cheatsheets/`, `highlight/context` | 3 |
| 1.1-6 | **Problems hygiene** | Drop a file's C diagnostics on close or delete; re-check sources that include an edited header; whole-project C check (⌘⇧B). | `check/`, `AppState+Check` | 3 |
| 1.1-7 | **Editor leftovers** | Gutter fold chevrons, bracket-pair highlight, Reformat Selection, Move Statement, Complete Statement, Replace in Project with preview, ⌫/↩ in the tree, nested snippet stops, outer signature after `)`. | `must_have.md` open items | 4 |
| 1.1-8 | **Ranking regression suite** | Golden top-3 per site against the fixture index in CI; app and CLI send identical queries. | `tests/ranking.rs` | 2 |
| 1.1-9 | **Extension-less C++ headers** | A file with no extension under a clang system include directory, or whose first 64 KB pass `is_cpp_header`, opens as C++ with the scrubbed parse the header cache already uses; go-to-definition into a system header opens it read-only. | `highlight/syntax.rs`, `BufferLanguage.swift`, `Definitions.swift` | 1 |
| 1.1-10 | **App integration test** | The `selftest` scene runs in CI on `samples/cpp-demo` and the demo crate and fails the build on any `FAIL` line; a completion scene asserts rows at a marker. | `RideTests`, CI | 2 |
| 1.1-11 | **Find Action (⇧⌘A)** | A command palette listing every menu command with its shortcut, plus files and symbols behind prefixes (`/` files, `@` symbols, `:` line), fuzzy-matched like Open Quickly; the `Commands` structs register their actions in a `CommandRegistry` so the palette and the menus share one table. Double-⇧ opens it too. | `app/Ride/Menus`, `app/Ride/Search` | 2 |
| 1.1-12 | **Quick Definition (⌥Space) and External Documentation (⇧F1)** | Quick Definition shows the definition's source excerpt (signature plus the first lines of the body) in the hover card without leaving the file; External Documentation opens docs.rs for catalog items (`crate/version/path`), cppreference for `std::` names, the local header otherwise. | `HoverController`, `Definitions.swift` | 2 |
| 1.1-13 | **Breadcrumbs** | The enclosing item path (`impl Counter › record`) in the status bar from the outline, clickable to open the symbol picker at that item. | `StatusBarView`, outline | 1 |

Exit criteria: two panes with independent popups; workspace reopens as left; update check installs a signed build; CI runs engine tests, app tests, ranking goldens and the self-test scene; every command is reachable from ⇧⌘A.

## Release 1.2 — Workbench (3–4 weeks)

Goal: the tasks around the code (shell, marks, history, todos) stay inside Ride, as they do in RustRover.

| # | Feature | Design notes | Where | Days |
|---|---|---|---|---|
| 1.2-1 | **Terminal panel (⌥F12)** | A bottom panel tab next to Problems hosting a real terminal emulator (SwiftTerm, MIT) over a pty running the user's shell in the workspace root; multiple tabs, Open in Terminal from the tree opens a tab at that folder, `path:line` in output is clickable, ⌘F searches output; the Run panel of 2.0 reuses the same view. | `app/Ride/Terminal` | 4 |
| 1.2-2 | **Bookmarks** | Toggle (F3), mnemonic bookmarks 0–9 (⌃0–9 to jump), next/previous (⌥F3 / ⇧⌥F3 to avoid the method keys), gutter glyph, a Bookmarks panel grouped by file, stored per workspace with the layout state. | `app/Ride/Bookmarks`, gutter | 2 |
| 1.2-3 | **Local History** | Every save and every external change writes a content-addressed snapshot under the support directory (5 working days retained, configurable); Show History opens a two-pane diff (snapshot list, unified diff with a Revert button) for the file or a folder; Put Label from the File menu. | `app/Ride/History`, `src/git/diff.rs` (shared with 2.0-3) | 3 |
| 1.2-4 | **TODO panel** | `TODO`, `FIXME`, `XXX`, `HACK` in comments across the workspace via the project-find scanner, grouped by file, refreshed on save; a preference for extra patterns. | `app/Ride/Search` | 1 |
| 1.2-5 | **Recent Locations (⇧⌘E)** | The navigation history as a picker with a two-line code preview per entry. | `app/Ride/Navigate` | 1 |
| 1.2-6 | **Crash and panic reports** | Last engine panic and the Swift crash log written to the support directory; on next launch a notice offers to open them. | `RideApp`, `engine` | 1 |
| 1.2-7 | **Accessibility** | Focus rings on custom controls, VoiceOver labels for popups and panels, Reduce Motion everywhere; About and Shortcuts demo scenes. | `app/Ride/Design` | 2 |

Exit criteria: build, run and grep from the terminal without leaving Ride; a bookmark survives a restart; a wrong save is undone from Local History.

## Release 1.3 — Understanding code (7–9 weeks)

Goal: answer "where is this used, what does this call, what type is this, how do I restructure it" without an LSP.

| # | Feature | Design notes | Where | Days |
|---|---|---|---|---|
| 1.3-1 | **Reference index** | Extract identifier *uses* per file with tree-sitter (calls, type mentions, field accesses) into a per-workspace Tantivy index keyed by name, kind, path and byte range; rebuilt incrementally on save via the existing overlay. Powers Find Usages (⌥F7) with a results panel grouped by file with the enclosing item; heuristic resolution ranks same name plus reachable definition first and lists the rest under "other matches". | `src/extract/refs.rs`, `src/index/refs.rs`, `app/Ride/Search` | 8 |
| 1.3-2 | **Rename (⇧F6)** | Buffer-local through tree-sitter scopes first; workspace-wide through the reference index with a preview sheet; `.h`/`.c` pairs together; inline rename box in the editor for locals. | `highlight/rename.rs`, `engine/edits.rs` | 5 |
| 1.3-3 | **Call hierarchy and outline peek** | Incoming/outgoing calls from the reference index in a side panel; outline rows peek signature and doc on hover. | `engine/symbols.rs`, `app/Ride/Outline` | 3 |
| 1.3-4 | **Semantic highlighting** | Locals, parameters, fields, types and functions colored from the `TypeTable` and outline; mutable and unused-local styling. | `highlight/spans.rs`, themes | 3 |
| 1.3-5 | **Inlay hints and Type Info (⌃⇧P)** | Type hints after `let` bindings from the receiver heuristics, parameter-name hints in calls from `params::names`, chained-method type hints where the receiver resolves; C/C++ `auto` from the `TypeTable`; a Type Info popup for the expression at the caret using the same resolver, saying "unknown" honestly. Hints off by default until the heuristics cover 80% of bindings in the samples. | `highlight/inlays.rs`, `RideTextView` | 6 |
| 1.3-6 | **Live diagnostics, Clippy** | Debounced background `cargo check --message-format json` into a temp target dir after edits; a preference switches the linter to `cargo clippy` with lint codes linking to the lint page; clang keeps `-fsyntax-only` per save plus the project check. | `check/run.rs`, `CheckService` | 4 |
| 1.3-7 | **Intention actions (⌥↩)** | One light-bulb menu at the caret: compiler quick fixes (`suggested_replacement`, clang fix-its), engine fixes (add missing `use` or `#include`, prefix unused with `_`, add missing `match` arms from the enum, implement missing trait items from the catalog signature), and the refactorings of 1.3-9 that apply to the selection. Gutter bulb colored by severity. | `check/message.rs`, `engine/fixes.rs`, app menu | 5 |
| 1.3-8 | **Cheat sheet explain mode** | Select code, ⌃⇧Space: reverse lookup of the selection's tree-sitter node kinds against sheet entries; entries gain optional `node` patterns. | `cheatsheet/explain.rs` | 4 |
| 1.3-9 | **Refactor menu** | Extract Variable (⌥⌘V: replace the selected expression with a `let` above the statement), Extract Function (⌥⌘M: parameters are identifiers declared outside the selection and used inside, return values are locals used after it; C gets an out parameter when more than one), Inline Variable/Function (⌥⌘N, single-use via the reference index), Introduce Constant (⌥⌘C), Change Signature (⌘F6: reorder, add, remove parameters with call sites rewritten from the reference index), Safe Delete (with the usages check), Move (a Rust item to another module with the `use` fixed up). Every refactoring previews its edits in the rename sheet. | `highlight/refactor/`, `engine/refactor.rs`, app preview sheet | 8 |

Exit criteria: Find Usages on `Counter::record` lists every call site; Rename across a `.h`/`.c` pair applies through the preview; Extract Function on a selection in `main.rs` compiles; Rust type errors appear within two seconds of typing.

## Release 2.0 — Working with code (10–12 weeks)

Goal: Ride runs, tests and debugs the project, not only edits it.

| # | Feature | Design notes | Where | Days |
|---|---|---|---|---|
| 2.0-1 | **Cargo panel, run configurations and Run panel** | A Cargo tab listing packages, targets (bin, lib, test, bench, example), features with checkboxes, and the common commands (build, run, test, clippy, doc, clean); Make and CMake targets from the outline. Run configurations (command, args, features, env, working dir, `RUST_BACKTRACE`) saved with the workspace; ▶ in the gutter next to `fn main`, `#[test]`, doc tests and benches; the Run panel is a terminal tab with clickable `path:line:col`, ANSI colors and test results parsed into pass/fail rows with rerun-failed. ⌘R runs, ⇧⌘R runs tests, ⌘F9 builds. | `src/run/`, `app/Ride/Cargo`, `app/Ride/Terminal` | 10 |
| 2.0-2 | **Debugger via LLDB** | `lldb-dap` over stdio; line, conditional and hit-count breakpoints in the gutter, panic and exception breakpoints, step controls, frames, locals with Rust renderers (`String`, `Vec`, `Option`, `HashMap`), watches, Evaluate Expression (⌥F8), hover to evaluate, attach to a running process. Rust and C/C++ with the Xcode lldb. | `src/debug/`, `app/Ride/Debug` | 14 |
| 2.0-3 | **Git integration** | Diff gutter markers per buffer with revert-hunk; Changes panel (stage, unstage, commit with message templates, amend); Annotate (blame) in the gutter; file and project history with diff; branches (create, checkout, merge); stash and unstash; a three-pane conflict resolver; all through the `git` CLI. | `src/git/`, `app/Ride/Git` | 10 |
| 2.0-4 | **Multi-root workspaces** | Several roots in one window (a Rust crate and its C dependency); the engine reads through a `Vfs` trait so a synced remote copy can be indexed locally later. | `discover/`, `Workspace.swift` | 5 |
| 2.0-5 | **Crate and header browser** | Sidebar tab listing every catalog crate (version, features, path) and include directory; public API outline per crate; pinned crates boost ranking; `Cargo.toml` inlay hints with the current and latest local version. | `query/crates.rs`, `app/Ride/Catalog` | 4 |
| 2.0-6 | **Extensible sheets and snippets** | User sheets under the support directory merged after the built-in ones; a preferences pane; export/import. | `cheatsheet/load.rs`, Preferences | 3 |
| 2.0-7 | **Optional local model rerank** (KD-2 preserved) | Off by default: a small ONNX embedder reranks the top 50 hits for phrase queries; never per keystroke; no network at query time. | `query/rerank.rs` | 6 |
| 2.0-8 | **Plugin surface** | The debug JSON-RPC becomes a documented local API: open file, query, check, run. No third-party code in-process. | `src/bin/ride_engine`, docs | 3 |
| 2.0-9 | **Macro expansion** | When `cargo-expand` is on PATH, Expand Macro (from ⌥↩ or the gutter) shows the expansion of the item at the caret in a read-only buffer; otherwise the menu item explains what to install. | `src/run/expand.rs` | 1 |
| 2.0-10 | **Share to Rust Playground** | Explicit menu action that posts the buffer to play.rust-lang.org and opens the returned link; the only outbound network call in Ride, behind a confirmation. | `AppState+Share` | 1 |

Exit criteria: run a failing test from the gutter, click the failure, set a breakpoint, step to the assertion, inspect a `Vec` local; commit the fix from the Changes panel.

## Continuous — engine hygiene and quality gates

- Latency gate in CI: completion p95 < 5 ms per site, cheat sheet and editor queries p95 < 1 ms on the fixture index; index size audit.
- FSEvents-driven index reload instead of the 250 ms manifest poll; incremental workspace reindex on save under 1 s.
- Header cache: skip libc++ `__cxx03/` copies; template-argument tracking in the `TypeTable`.
- Re-exports from workspace crates that re-export dependency items resolve to the real kind.
- The `selftest` scene grows with every new command; every menu item stays reachable from Find Action.

## Sequencing and dependencies

```
1.1-1 split ──► 1.3-3 call hierarchy panel ──► 2.0-2 debugger panels
1.1-8 goldens ──► 1.3-1 reference index (same fixture, same CI job)
1.1-11 find action ──► 1.3-7 intentions (same command registry)
1.2-1 terminal ──► 2.0-1 run panel (same view)
1.2-3 local history diff ──► 2.0-3 git diff and conflicts (same diff engine)
1.3-1 references ──► 1.3-2 rename ──► 1.3-9 refactor menu ──► 1.3-7 intentions
1.3-4 semantic highlight ──► 1.3-5 inlays and type info (shared resolver)
1.3-6 live check ──► 1.3-7 intentions
2.0-1 run panel ──► 2.0-2 debugger (shares target discovery)
```

1.1 is trust and structure. 1.2 is cheap, visible and what RustRover users miss first (terminal, bookmarks, history). 1.3 is the highest-value engineering: the reference index turns names into a model of the project, and rename, refactorings, hierarchy, hints and intentions all read it. 2.0 is where Ride becomes an IDE; the debugger is the largest item and the one most users will judge it by.

## Tradeoffs and non-goals

- **Heuristic references and refactorings over a type checker.** Tree-sitter scopes plus reachability cover locals, items and the common cross-file cases; anything unresolved is shown as "other matches" and refactorings refuse rather than guess. rust-analyzer stays out (KD-6).
- **SwiftTerm over a home-grown terminal.** A terminal emulator is a product of its own; a mature MIT package is the only third-party UI dependency the roadmap adds.
- **LLDB over a custom debugger.** `lldb-dap` ships with Xcode and understands Rust and C++.
- **Local model only as a rerank.** KD-2 stands; the Playground share is the one explicit outbound call.
- **Git through the CLI.** libgit2 adds a large dependency for features the CLI provides.
- **No language server hosting, no coverage or profiler UI, no database or HTTP tooling, no GitHub PR client in 2.0.**

## Suggested next step

Start 1.1 with the editor split (1.1-1) and the CI gates (1.1-8, 1.1-10), then Find Action (1.1-11) so every command added afterwards is discoverable, and ship 1.1 with the update check so later releases reach users automatically.
