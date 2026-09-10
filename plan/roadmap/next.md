# Ride — Next features and roadmap (2026-09-10)

| Field | Value |
|---|---|
| Baseline | 1.0 backlog done except A3 split, update check and universal build (`improve-extend.md`); completion phases 1–5 done (`completion.md`); cheat sheet shipped (`cheatsheet.md`) |
| Principle | Keep KD-1/2/6: Swift shell, Rust engine, no cloud model, no LSP dependency. Everything below runs locally and answers in milliseconds. |
| Horizon | Three releases: 1.1 (polish and trust), 1.2 (understanding code), 2.0 (working with code) |
| Prerequisite | `plan/roadmap/must_have.md` (editor basics: indent, comment, line commands, navigation, folding) ships first |

## What Ride is good at today

- Sub-millisecond completion over the buffer, the workspace and every crate on disk, with site classification, snippets, auto-import, signature help and a doc card.
- C/C++ editing that follows headers through the compile database, including `std::` from libc++.
- A context-aware cheat sheet for Rust, C, C++ and Make with 1,900 insertable templates.
- Diagnostics from `cargo check` and `clang -fsyntax-only`, formatting, go to definition, hover, symbol and text search, markdown preview, light and dark themes, demo scenes for screenshot review.

## What holds it back

1. **One buffer at a time.** No editor split, no side-by-side header/source (A3 blocked on the `EditorJump` singleton). Blocks the most common C/C++ workflow.
2. **Symbols are names, not references.** The engine knows definitions but not uses, so there is no find-references, rename, or call hierarchy.
3. **Diagnostics are per save.** No per-keystroke type errors, no quick fixes, no whole-project C check.
4. **The cheat sheet stops at insertion.** It does not explain the code the user already has, and TOML/CMake have no sheets.
5. **Trust and distribution.** No update check, no crash reporting, no universal build, no test of the app against a real workspace in CI.

## Release 1.1 — Polish and trust (3–4 weeks)

Goal: a daily driver a Rust/C developer keeps open all day.

| # | Feature | Design notes | Where | Days |
|---|---|---|---|---|
| 1.1-1 | **Editor split** (A3) | Replace the `EditorJump` singleton with a per-pane `EditorHost` registry keyed by pane id; `AppState` tracks the focused pane; open-in-split from the tree, ⌘\ to split, drag tabs between panes. Header/source toggle (⌃⌥↑) opens the sibling in the other pane. | `app/Ride/Editor`, `AppState+Layout` | 5 |
| 1.1-2 | **Persistent workspace state** | Open tabs, split layout, caret per file, folded panels restored per workspace root (`~/Library/Application Support/Ride/workspaces/<hash>.json`). | `app/Ride/Workspace` | 2 |
| 1.1-3 | **Update check** (Phase 5) | Sparkle with the appcast published by `scripts/release.sh`; menu item Check for Updates; no telemetry. | `scripts/`, `RideApp` | 2 |
| 1.1-4 | **Universal build** | x86_64 xcframework slice; CI matrix. | `scripts/build-engine.sh`, CI | 1 |
| 1.1-5 | **Cheat sheet follow-ups** | Sheets for TOML (Cargo manifest keys and tables) and CMake (commands, common variables); `case`/`default` context in `switch`; syntax-highlighted preview through the engine highlighter; per-line debounce in pinned mode. | `cheatsheets/`, `highlight/context`, `CheatSheetPreview` | 3 |
| 1.1-6 | **Problems hygiene** | Drop a file's C diagnostics when it closes or is deleted; re-check sources that include an edited header; whole-project C check over `compile_commands.json` (⌘⇧B). | `check/`, `AppState+Check` | 3 |
| 1.1-7 | **Snippet and signature edge cases** | Nested snippet inside a placeholder keeps the outer stops; signature help returns to the outer call after `)`. | `SnippetSession`, `SignatureHelpController` | 2 |
| 1.1-8 | **Ranking regression suite** | Golden top-3 per site against the fixture index in CI; app and CLI send identical queries (`Has` discrepancy). | `tests/ranking.rs` | 2 |
| 1.1-9 | **Extension-less C++ headers** | Opening `memory`, `vector` or `string` (from `#include <memory>` go-to-definition or the tree) shows no highlighting: `BufferLanguage.of` maps no extension to plain and `Lang::for_path` falls back to Rust, while the header cache already parses these files as C++. Detect them the way the cache does: a file with no extension whose path lies under a clang system include directory, or whose first 64 KB pass `is_cpp_header` (`namespace`, `template`, `_LIBCPP_*`, `#pragma GCC system_header`), opens as C++; the app takes the language from `SessionOpen.lang` as it already does for sniffed `.h` files, and go-to-definition into a system header opens it read-only with the same scrubbed parse the cache uses. | `highlight/syntax.rs::for_buffer`, `BufferLanguage.swift`, `Definitions.swift` | 1 |
| 1.1-10 | **App integration test** | `xcodebuild test` scene that opens `samples/cpp-demo`, triggers completion at a marker and asserts rows, replacing screenshot-only review for the hot path. | `RideTests` | 2 |

Exit criteria: two panes side by side with independent completion popups; workspace reopens exactly as left; update check installs a signed build; CI runs engine tests, app tests, ranking goldens and the integration scene.

## Release 1.2 — Understanding code (5–7 weeks)

Goal: answer "where is this used, what does this call, what type is this" without an LSP.

| # | Feature | Design notes | Where | Days |
|---|---|---|---|---|
| 1.2-1 | **Reference index** | Extract identifier *uses* per file with tree-sitter (calls, type mentions, field accesses) into a per-workspace Tantivy index keyed by `name` + `kind` + `path` + byte range; rebuilt incrementally on save via the existing overlay. Powers Find References (⇧F12) with a results panel like Find in Project, grouped by file, with the enclosing item shown. Heuristic resolution: same name plus reachable definition (imports, `impl` type, header includes) ranks first; unresolved same-name hits are listed under "other matches". | `src/extract/refs.rs`, `src/index/refs.rs`, `app/Ride/Search` | 8 |
| 1.2-2 | **Rename symbol** (⌘R in editor) | Buffer-local rename through tree-sitter scopes (locals, params, fields, items) first; workspace-wide through the reference index with a preview sheet listing every edit before applying; `.h`/`.c` pairs handled together. | `highlight/rename.rs`, `engine/edits.rs`, app preview sheet | 5 |
| 1.2-3 | **Call hierarchy and outline peek** | Incoming/outgoing calls from the reference index in a side panel; the outline gains a "peek" hover showing the item's signature and doc. | `engine/symbols.rs`, `app/Ride/Outline` | 3 |
| 1.2-4 | **Inline type hints** | Rust: types from the existing receiver heuristics (`let x = Vec::new()` → `: Vec<_>`) rendered as dimmed inlay text after `let` bindings and as parameter-name hints in calls (from `params::names`). C/C++: `auto` resolution from the `TypeTable`. Off by default until the heuristics cover 80% of bindings in the samples. | `highlight/inlays.rs`, `RideTextView` rendering attributes | 5 |
| 1.2-5 | **Semantic highlighting** | Color locals, parameters, fields, types and functions from the `TypeTable` and outline instead of the grammar alone; unresolved names stay plain. Enables "mutable variable" and "unused local" styling. | `highlight/spans.rs`, themes | 3 |
| 1.2-6 | **Live diagnostics for Rust** | A background `cargo check --message-format json` on a debounced 1.5 s timer after edits (writing to a temp target dir so saves are not required), reusing the existing diagnostic parser. Keep save-time check as the fallback. | `check/run.rs`, `CheckService` | 3 |
| 1.2-7 | **Quick fixes** | Light-bulb actions from diagnostics that carry a suggested replacement (`cargo check` `suggested_replacement`, clang `fix-it`), plus engine-provided fixes: add missing `use`, prefix unused with `_`, add missing `#include` for a known header symbol. | `check/message.rs`, `engine/fixes.rs`, app action menu | 4 |
| 1.2-8 | **Cheat sheet explain mode** | Select code, press ⌃⇧Space: the engine matches the selection's syntax (tree-sitter node kinds) against sheet entries and shows the matching section as documentation of what the user already wrote (reverse lookup). No model needed; entries gain optional `node` patterns. | `cheatsheet/explain.rs`, `CheatSheetController` | 4 |

Exit criteria: Find References on `Counter::record` in the demo lists every call site with the enclosing function; Rename across a `.h`/`.c` pair applies through a preview; Rust type errors appear within two seconds of typing without saving.

## Release 2.0 — Working with code (8–10 weeks)

Goal: Ride runs, tests and debugs the project, not only edits it.

| # | Feature | Design notes | Where | Days |
|---|---|---|---|---|
| 2.0-1 | **Run and test panel** | Cargo targets, Make targets and CMake targets discovered from the outline/`cargo metadata`; run with a play button or ⌘R; output in a bottom console with ANSI colors, clickable `path:line:col` links, and test results parsed from `cargo test` / ctest into pass/fail rows with gutter markers to run a single test. | `src/run/`, `app/Ride/Console` | 8 |
| 2.0-2 | **Debugger via LLDB** | `lldb` driven through its Python-free MI/JSON (`lldb --batch` first, then `lldb-dap` over stdio); breakpoints in the gutter, step controls, locals and call stack panels, hover to evaluate. Rust and C/C++ both work with the Xcode-provided lldb. | `src/debug/`, `app/Ride/Debug` | 12 |
| 2.0-3 | **Git integration** | Beyond badges: diff gutter markers from `git diff` per buffer, a Changes panel with stage/unstage/commit, blame in hover, checkout of branches. Uses the `git` CLI, no libgit2. | `src/git/`, `app/Ride/Git` | 8 |
| 2.0-4 | **Multi-root workspaces and remote folders** | Several roots in one window (a Rust crate and its C dependency); SSH-mounted folders via `sshfs`-free approach: engine reads through a `Vfs` trait with a local and an `ssh`/`rsync` implementation, indexing done locally on the synced copy. | `discover/`, `Workspace.swift` | 6 |
| 2.0-5 | **Crate and header browser** | A sidebar tab listing every crate in the catalog (version, features, path) and every include directory; open the source, see the public API outline, search within one crate; mark a crate as "pinned" to boost its ranking. | `query/crates.rs`, `app/Ride/Catalog` | 4 |
| 2.0-6 | **Extensible sheets and snippets** | User sheets in `~/Library/Application Support/Ride/cheatsheets/<lang>/*.toml` merged after the built-in ones; a Snippets preferences pane listing them; export/import as a folder. | `cheatsheet/load.rs`, Preferences | 3 |
| 2.0-7 | **Optional local model rerank** (KD-2 preserved) | Behind a preference and off by default: a small ONNX embedder (`fastembed`) reranks the top 50 completion or symbol-search hits for phrase queries ("retry with backoff"); never in the per-keystroke path; models stored locally, no network at query time. | `query/rerank.rs` | 6 |
| 2.0-8 | **Plugin surface** | A read-only JSON-RPC over localhost (debug-only today) becomes a documented local API for scripts: open file, query completions, run check. No third-party code inside the process. | `src/bin/ride_engine`, docs | 3 |

Exit criteria: run a failing `cargo test`, click the failure, set a breakpoint, step to the assertion, inspect a local; commit the fix from the Changes panel.

## Continuous — engine hygiene and quality gates

- Latency gate in CI: completion p95 < 5 ms per site on the fixture index; cheat sheet p95 < 1 ms; index size audit (drop stored fields the app never reads).
- FSEvents-driven index reload instead of the 250 ms manifest poll; incremental workspace reindex on save under 1 s stays the bar.
- Header cache: skip libc++ `__cxx03/` copies; template-argument tracking in the `TypeTable` so range-for over `std::vector<T>` types its element.
- Re-exports from workspace crates that re-export dependency items resolve to the real kind.
- Accessibility: focus rings on custom controls, VoiceOver labels for the popups, Reduce Motion respected everywhere; About and Shortcuts scenes for screenshot review.
- Crash reporting that stays local: write the last panic and the Swift crash log to the support directory and offer to open it on next launch.

## Sequencing and dependencies

```
1.1-1 split ──► 1.2-3 call hierarchy panel ──► 2.0-2 debugger panels
1.1-8 goldens ──► 1.2-1 reference index (same fixture, same CI job)
1.2-1 references ──► 1.2-2 rename ──► 1.2-3 hierarchy
1.2-5 semantic highlight ──► 1.2-4 inlays (shared name resolution)
1.2-6 live check ──► 1.2-7 quick fixes
2.0-1 run panel ──► 2.0-2 debugger (shares the console and target discovery)
```

1.1 is polish that unblocks structure (split, state, CI). 1.2 is the highest-value engineering: the reference index turns the catalog from "names" into "a model of the project" and everything after it (rename, hierarchy, hints, fixes) reads that model. 2.0 is where Ride stops being an editor and becomes an IDE; the debugger is the largest single item and the one most users will judge it by.

## Tradeoffs and non-goals

- **Heuristic references over a type checker.** A full Rust type checker is out of reach; tree-sitter uses plus reachability resolve the common cases and label the rest as "other matches". rust-analyzer stays out (KD-6): its latency and memory would dominate the product, and Ride's value is the instant, on-disk-corpus answer.
- **LLDB over a custom debugger.** `lldb-dap` ships with Xcode and understands Rust and C++; writing a debugger protocol client is far cheaper than a debugger.
- **Local model only as a rerank.** KD-2 stands: no cloud calls, nothing neural in the keystroke path. The embedder is an optional second pass over a few dozen hits for phrase queries.
- **Git through the CLI.** libgit2 bindings add a large dependency for features the CLI already provides; latency is fine for per-buffer diffs.
- **No language server hosting in 2.0.** Hosting third-party LSPs would make Ride a generic client; the roadmap keeps the built-in engine the source of truth and adds an opt-in external server only if a language outside Rust/C/C++ becomes a target.

## Suggested next step

Start 1.1 with the editor split (1.1-1) and the ranking goldens plus integration scene (1.1-8, 1.1-9), since both unblock everything after them, then ship 1.1 with the update check so later releases reach users automatically.
