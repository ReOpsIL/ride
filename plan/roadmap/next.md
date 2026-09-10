# Ride — Next features and roadmap (2026-09-10, trimmed to daily native-app work after the RustRover and CLion pass)

| Field | Value |
|---|---|
| Scope | What a developer building native apps in Rust, C and C++ needs every day. Everything that is not on that path was removed (see "Cut"). |
| Baseline | 1.0 backlog done except A3 split, update check and universal build; completion phases 1–5, cheat sheet and the editor must-haves (`must_have.md`) shipped |
| Principle | KD-1/2/6: Swift shell, Rust engine, no cloud model, no LSP dependency; local and fast |
| Reference | RustRover: [quick start](https://www.jetbrains.com/help/rust/quick-start-guide-rustrover.html), [reference views](https://www.jetbrains.com/help/rust/viewing-reference-information.html), [inspections](https://www.jetbrains.com/help/rust/code-inspection.html), [terminal](https://www.jetbrains.com/help/rust/terminal-emulator.html), [debugging](https://www.jetbrains.com/help/rust/debugging-code.html). CLion: [quick start](https://www.jetbrains.com/help/clion/clion-quick-start-guide.html), [code generation](https://www.jetbrains.com/help/clion/generating-code.html), [code analysis](https://www.jetbrains.com/help/clion/code-analysis.html), [compilation database](https://www.jetbrains.com/help/clion/compilation-database.html) |
| Horizon | 1.1 Trust · 1.2 Build, run, test, debug · 1.3 Understand and change code · 2.0 Git |

## What CLion adds to the picture

CLion is organised around the **project model** (CMake first, then Makefile and compilation-database projects), and everything else hangs off it: targets become run/debug configurations, the debugger and the test runner attach to targets, single files can be compiled and run without a project, and the Generate menu (⌘N in CLion) writes the C++ boilerplate (constructors, getters and setters, operators, override and implement, definitions in the `.cpp`). Analysis runs on the fly through clangd with Clang-Tidy as the checker. For Ride this means the build-run-test-debug loop moves ahead of the reference index: a native-app developer runs and debugs many times a day and renames rarely.

## Cut from the previous draft

Not on the daily path for native-app work, so removed rather than deferred: Find Action palette, breadcrumbs, TODO panel, bookmarks, Recent Locations, cheat sheet explain mode, user-extensible sheets, crate and header browser, local model rerank, plugin JSON-RPC surface, macro expansion, Rust Playground share, multi-root and remote workspaces, `Cargo.toml` version hints, accessibility and crash reports as features (both stay as hygiene below).

## What holds Ride back

1. **One buffer at a time.** No split, no header next to source.
2. **Nothing runs.** No build target list, no run or debug, no test runner; the loop goes through the terminal.
3. **Symbols are names.** No usages, rename, refactorings, generated code or live diagnostics.
4. **No Git beyond badges.**

## Release 1.1 — Trust (3–4 weeks)

| # | Feature | Design notes | Where | Days |
|---|---|---|---|---|
| 1.1-1 | **Editor split** | Replace the `EditorJump` singleton with a per-pane host registry; open-in-split, ⌘\, drag tabs; Switch Header/Source (F10 alias) opens the sibling in the other pane. | `app/Ride/Editor` | 5 |
| 1.1-2 | **Persistent workspace state** | Tabs, split, caret and folds per file, panel sizes, per workspace root. | `app/Ride/Workspace` | 2 |
| 1.1-3 | **Update check and universal build** | Sparkle appcast from `scripts/release.sh`; x86_64 slice; CI matrix. | `scripts/`, CI | 3 |
| 1.1-4 | **Editor leftovers** | Fold chevrons, bracket-pair highlight, Reformat Selection, Move Statement, Complete Statement, Replace in Project, ⌫/↩ in the tree, nested snippet stops, outer signature after `)`. | `must_have.md` open items | 4 |
| 1.1-5 | **Extension-less C++ headers** | A file with no extension under a system include directory or passing `is_cpp_header` opens as C++ with the scrubbed parse; definitions into system headers open read-only. | `highlight/syntax.rs`, `BufferLanguage.swift` | 1 |
| 1.1-6 | **Problems hygiene and project C check** | Drop a file's C diagnostics on close; re-check sources that include an edited header; whole-project check over `compile_commands.json` (⇧⌘B). | `check/` | 3 |
| 1.1-7 | **CMake and TOML sheets** | The two missing cheat sheets; `case`/`default` context. | `cheatsheets/` | 2 |
| 1.1-8 | **CI gates** | Ranking goldens per site; the `selftest` scene on `samples/cpp-demo` and the demo crate failing the build on any `FAIL`. | `tests/`, CI | 3 |
| 1.1-9 | **Quick Documentation (⌃J, F1)** | The whole doc comment of the item under the caret, rendered: the engine re-reads the item's source at its stored path and byte offset and lifts the full `///`, `//!`, `/** */` or Doxygen block (nothing new stored in the index), renders it with `render_markdown` (headings, lists, highlighted fences, tables) and resolves intra-doc links (`[File::open]`, `[`io::Read`]`) through the catalog so a click opens that item's doc. Shown in a themed web view popup that scrolls, resizes and pins; hover keeps the one-paragraph card and expands to the full doc on ⌃J or a click; ⌘I in the completion popup opens the same view. ⇧F1 opens docs.rs for catalog items or cppreference for `std::` in the browser. | `engine/docs.rs`, `HoverPanel`, `CompletionDocCard` | 4 |
| 1.1-10 | **Quick Definition (⌥Space)** | The definition's source in a peek popup without leaving the file: the engine returns the item's source excerpt (signature and body, capped at 60 lines) from the buffer, a reachable header or the catalog file at its stored offset, with highlight spans from `source_highlights`; the popup shares the frame, pin and resize behaviour of 1.1-9, shows `path:line` in its header with an Open button (F12) and, for a symbol with several definitions (a C declaration and its definition, a trait method and its impls), a list to switch between them. ⌘-hover keeps the one-line signature. | `engine/docs.rs`, `PeekPanel` | 2 |

Exit: two panes with independent popups; workspace reopens as left; update check installs a signed build; CI runs engine, app, goldens and self-test.

## Release 1.2 — Build, run, test, debug (7–9 weeks)

Goal: the CLion loop. Targets come from the project model, run and debug attach to targets, tests run from the gutter.

| # | Feature | Design notes | Where | Days |
|---|---|---|---|---|
| 1.2-1 | **Project model** | One `ProjectModel` per workspace root, detected in this order: Cargo (`cargo metadata`: packages, bin/lib/test/bench/example targets, features), CMake (`CMakeLists.txt`: configure into `build/<profile>` with `CMAKE_EXPORT_COMPILE_COMMANDS=ON`, read the CMake File API for targets, so the compile database Ride already uses is produced automatically), Makefile (targets from the outline, `make -n` to learn the commands), compilation database only (targets are the listed sources; build through a user command like CLion's custom build target). Reload on manifest change. A Targets panel lists them with build type profiles (Debug, Release, RelWithDebInfo) for CMake. | `src/project/`, `app/Ride/Project` | 8 |
| 1.2-2 | **Run configurations** | Per target: command, arguments, environment, working directory, `RUST_BACKTRACE`, sanitizer flags (ASan/UBSan/TSan as a checkbox that adds the compile and env flags for CMake and Cargo), saved with the workspace; a toolbar target picker; ⌘R runs, ⌘B builds, ⇧⌘R runs tests, ⌃⌘R debugs (CLion: ⇧F10/⇧F9). | `app/Ride/Run` | 4 |
| 1.2-3 | **Terminal and Run console** | A bottom panel tab on SwiftTerm over a pty for the shell (⌥F12, Open in Terminal from the tree, multiple tabs); the Run console is the same view with `path:line:col` clickable, ANSI colors, Stop and Rerun; build errors from the console feed the Problems panel through the existing parsers. | `app/Ride/Terminal` | 5 |
| 1.2-4 | **Test runner** | `cargo test` (JSON via `--format json` when available, otherwise parsed output), GoogleTest and Catch2 through their `--gtest_list_tests` / `--list-tests` and result output, CTest through `ctest --show-only=json-v1`; ▶ in the gutter next to `#[test]`, `TEST(...)`, `TEST_CASE(...)` and `fn main`; a Tests panel with pass/fail tree, output per test, rerun failed, filter. | `src/run/tests/`, `app/Ride/Tests` | 6 |
| 1.2-5 | **Single-file run and recompile** | Run the current `.c`, `.cpp` or `.rs` file without a project (clang / rustc into a temp dir) and Recompile File (⇧⌘F9) for compilation-database projects using that file's command. | `src/run/single.rs` | 2 |
| 1.2-6 | **Debugger via LLDB** | `lldb-dap` over stdio from Xcode: line, conditional and hit-count breakpoints in the gutter, panic and exception breakpoints, step in/over/out, continue, frames, locals with Rust renderers (`String`, `Vec`, `Option`, `HashMap`) and C++ STL, watches, Evaluate Expression (⌥F8), hover to evaluate, attach to process, Debug panel with threads. | `src/debug/`, `app/Ride/Debug` | 14 |

Exit: open `samples/cpp-demo`, pick the target, ⌘R runs it, a failing GoogleTest shows in the Tests panel, a breakpoint stops the debugger and a `std::vector` local expands.

## Release 1.3 — Understand and change code (8–10 weeks)

| # | Feature | Design notes | Where | Days |
|---|---|---|---|---|
| 1.3-1 | **Reference index and Find Usages (⌥F7)** | Tree-sitter uses per file (calls, type mentions, field accesses) in a per-workspace Tantivy index rebuilt incrementally on save; results grouped by file with the enclosing item; same name plus reachable definition ranks first, the rest under "other matches". Code vision: a dimmed "N usages" line above each item from the same index, click to open the usages. | `src/extract/refs.rs`, `src/index/refs.rs` | 8 |
| 1.3-2 | **Rename (⇧F6)** | Buffer-local through scopes, workspace-wide through the index with a preview sheet; `.h`/`.cpp` pairs together; inline rename box for locals. | `highlight/rename.rs` | 5 |
| 1.3-3 | **Generate (⌘N in the editor)** | C++: constructor from fields, destructor, getters and setters, `operator==`/`!=`, relational operators, `operator<<`, override virtual functions and implement pure ones from the base class in the `TypeTable`, definitions in the `.cpp` for declared methods, include guard or `#pragma once`. Rust: `impl` block for a struct, `impl Trait for` with the trait's required items from the catalog signature, `Default`, `Display`, `new`. Create from usage (⌥↩ on an unresolved call): stub function or method with parameters from the arguments. | `engine/generate.rs`, app menu | 6 |
| 1.3-4 | **Refactor menu** | Extract Variable (⌥⌘V), Extract Function (⌥⌘M, parameters from free identifiers, return values from locals used after, C gets an out parameter), Inline (⌥⌘N), Introduce Constant (⌥⌘C), Change Signature (⌘F6 with call sites from the index), Safe Delete; every refactoring previews in the rename sheet. | `highlight/refactor/`, `engine/refactor.rs` | 8 |
| 1.3-5 | **Live diagnostics, Clippy, Clang-Tidy** | Debounced background `cargo check` (or `cargo clippy` by preference) into a temp target dir; clang `-fsyntax-only` per edit for the current file plus `clang-tidy` (when installed, checks from `.clang-tidy`) on save and in the project check; lint codes link to their pages. | `check/` | 5 |
| 1.3-6 | **Intention actions (⌥↩)** | One light-bulb menu: compiler quick fixes (`suggested_replacement`, clang fix-its), engine fixes (add missing `use` or `#include`, `_` for unused, missing `match` arms, implement missing trait items), create-from-usage, and the refactorings that apply to the selection. | `engine/fixes.rs` | 5 |
| 1.3-7 | **Semantic highlighting, inlay hints, Type Info (⌃⇧P)** | Locals, parameters, fields, types and functions colored from the `TypeTable`; type hints after `let` and for `auto`, parameter-name hints in calls; a Type Info popup from the same resolver that says "unknown" when it is. Hints off by default until the samples resolve 80% of bindings. | `highlight/spans.rs`, `highlight/inlays.rs` | 8 |
| 1.3-8 | **Call and type hierarchy** | Incoming/outgoing calls from the reference index (⌃⌥H); C++ and Rust trait type hierarchy from the `TypeTable` and catalog (⌃H); both in a side panel. | `engine/symbols.rs`, `app/Ride/Outline` | 4 |

Exit: Find Usages on `Counter::record` lists every call; Rename across a header pair applies through the preview; Generate writes a constructor and getters for `geo::Rect`; Extract Function on a selection compiles; type errors appear within two seconds of typing.

## Release 2.0 — Git (4–5 weeks)

| # | Feature | Design notes | Where | Days |
|---|---|---|---|---|
| 2.0-1 | **Changes and commit** | Diff gutter markers per buffer with revert hunk; Changes panel with stage, unstage, commit, amend; commit message with the current diff visible. | `src/git/`, `app/Ride/Git` | 6 |
| 2.0-2 | **History, blame, branches** | File and project history with diff; Annotate in the gutter; branch create, checkout, merge; stash and unstash. | `app/Ride/Git` | 5 |
| 2.0-3 | **Conflicts** | Three-pane resolver on merge conflicts; the Problems panel lists conflicted files. | `app/Ride/Git` | 4 |
| 2.0-4 | **Local History** | Snapshot per save under the support directory, five working days, Show History with diff and revert. Shares the diff engine with 2.0-1. | `app/Ride/History` | 3 |

All through the `git` CLI; no libgit2, no hosting-service client.

## Continuous — hygiene

- Latency gate in CI: completion p95 < 5 ms per site, editor queries p95 < 1 ms; index size audit.
- FSEvents-driven index reload; incremental workspace reindex under 1 s.
- Header cache: skip libc++ `__cxx03/`; template-argument tracking in the `TypeTable` (range-for over `std::vector<T>`).
- Crash and panic logs written to the support directory with a notice on next launch; VoiceOver labels and focus rings on custom controls; the `selftest` scene grows with every command.

## Sequencing

```
1.1-1 split ──► 1.2-6 debugger panels, 1.3-8 hierarchy panels
1.1-8 goldens ──► 1.3-1 reference index (same fixture, same CI job)
1.2-1 project model ──► 1.2-2 run configs ──► 1.2-4 tests ──► 1.2-6 debugger
1.2-3 terminal ──► run console, test output
1.3-1 references ──► 1.3-2 rename ──► 1.3-4 refactors ──► 1.3-6 intentions
1.3-5 live check ──► 1.3-6 intentions
1.3-7 resolver ──► 1.3-3 generate (base classes, trait items)
2.0-4 local history ◄── diff engine ──► 2.0-1 changes
```

1.2 comes before 1.3 on purpose: a native-app developer runs, tests and debugs many times a day and renames or extracts occasionally, and CLion users judge an IDE by the build-run-debug loop first.

## Tradeoffs and non-goals

- **CMake through its File API and a generated compile database**, not a custom CMake parser: Ride keeps using `compile_commands.json` for completion and diagnostics, and configuring CMake once per profile produces it.
- **Heuristic references and refactorings over a type checker**; unresolved names are shown as "other matches" and refactorings refuse rather than guess. rust-analyzer and clangd stay out.
- **LLDB over a custom debugger**; SwiftTerm over a home-grown terminal; Git through the CLI.
- **Not planned:** coverage and profiler UIs, sanitizer report viewers beyond the console, Valgrind, Meson or Gradle models, remote development, database and HTTP tooling, GitHub PR client, plugins, any model in the keystroke path.

## Suggested next step

Ship 1.1 quickly (split, persistence, updates, CI gates), then start 1.2 with the project model and run configurations, since the test runner and debugger both attach to them.
