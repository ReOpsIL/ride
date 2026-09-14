# Ride — Next features after 1.2 (2026-09-12): coding, completion, running and debugging

| Field | Value |
|---|---|
| Baseline | 1.1 and 1.2 complete on `grok/next-impl` (`plan/roadmap/next-impl.md` section 7); the run, test and debug loop works live for Rust and is built but unverified live for C and C++ (`docs/product/feature-inventory.md`) |
| Principle | KD-1/2/6 unchanged: Swift shell, Rust engine, no cloud model, no LSP dependency. Heuristics over a type checker; refactorings refuse rather than guess |
| Horizon | 1.3 Understand and change code (8–10 weeks) · 1.4 Completion that knows types (5–6 weeks) · 1.5 Debugging depth and assembly (6–8 weeks) |
| Execution | Cards in the `next-impl.md` style, Opus executors per card, Sonnet reviews, the strong model on Tier C items |

## Where the code stands

**Coding.** Symbols are still names: F12 finds definitions in the buffer, headers and the catalog, but there is no usages index, no rename, no generated code, no refactoring, no live diagnostics while typing (checks run on save or ⌥⌘B), no intention menu. Highlighting is syntactic; the `TypeTable` resolves receivers for member completion but does not colour locals or parameters.

**Completion.** Six sites (`Identifier`, `MemberAccess`, `UsePath`, `ScopedPath`, `Include`, `Directive`) answered in under a millisecond, with buffer locals, workspace items, the crate catalog, header items, keywords, postfix templates, struct-literal fields, attributes, call snippets and auto-import edits. Ranking goldens gate CI. Gaps: members of a call's return value (`foo().bar`), chained calls, generic and template arguments (`Vec<T>` members typed as `T`, `std::vector<Widget>` range-for), trait methods on a receiver, closure parameter types, argument-position completion (an enum variant or constant that fits the parameter), C++ overload sets in one row, `this->` in templates, Rust macro bodies, and no completion at all in TOML values, CMake arguments beyond keywords, or Markdown.

**Running and debugging.** Verified live for Rust; C and C++ paths are implemented and covered by fixtures but never run end to end. Missing: attach to process, debugging a single test from its gutter marker, memory and heap views, watchpoints, disassembly and instruction stepping, core files, any assembly support, a CMake profile switch that re-detects, run configurations for GoogleTest and Catch2 binaries as first-class targets, and a C++ live self-test in CI.

## Release 1.3 — Understand and change code

| # | Feature | Design notes | Tier | Days |
|---|---|---|---|---|
| 1.3-1 | **Reference index and Find Usages (⌥F7)** | Tree-sitter uses per file (calls, type mentions, field accesses, `use` paths, `#include`) into a per-workspace Tantivy index rebuilt incrementally on save; results grouped by file with the enclosing item; a hit with a reachable definition of the same name ranks first, the rest under "other matches". Code vision: a dimmed "N usages" line above items. | C (schema, incremental rebuild, ranking) then A (per-language extractors) | 8 |
| 1.3-2 | **Rename (⇧F6)** | Buffer-local through the existing scopes with an inline box; workspace-wide through 1.3-1 with a preview sheet; `.h`/`.cpp` pairs together. | B | 5 |
| 1.3-3 | **Live diagnostics** | Debounced `cargo check` (or `clippy` by preference) into a temp target dir 800 ms after the last edit; `clang -fsyntax-only` per edit for the current C/C++ file with the compile-database flags; `clang-tidy` on save when installed with `.clang-tidy`; lint codes link to their pages. Reuses the build-diagnostics owner model from 1.2. | A | 5 |
| 1.3-4 | **Generate (⌘N in the editor)** | C++: constructor from fields, destructor, getters and setters, `operator==`/`!=` and relational operators, `operator<<`, override virtuals and implement pure ones from the `TypeTable`, definitions in the `.cpp`, `#pragma once`. Rust: `impl` block, `impl Trait for` with required items from the catalog signature, `Default`, `Display`, `new`. Create from usage on an unresolved call. | A per generator | 6 |
| 1.3-5 | **Intention actions (⌥↩)** | One light-bulb menu: compiler quick fixes (`suggested_replacement`, clang fix-its), engine fixes (add `use` or `#include`, `_` prefix, missing `match` arms, implement missing trait items), create-from-usage, applicable refactorings. | B | 5 |
| 1.3-6 | **Refactor menu** | Extract Variable (⌥⌘V), Extract Function (⌥⌘M with parameters from free identifiers and an out parameter for C), Inline (⌥⌘N), Introduce Constant (⌥⌘C), Change Signature (⌘F6 through the index), Safe Delete; every refactoring previews in the rename sheet and refuses when the heuristic is unsure. | C (extract function, change signature), A (the rest) | 8 |
| 1.3-7 | **Semantic highlighting, inlay hints, Type Info (⌃⇧P)** | Locals, parameters, fields, types and functions coloured from the `TypeTable`; type hints after `let` and for `auto`, parameter-name hints in calls; a Type Info popup that says "unknown" honestly. Hints off by default until the samples resolve 80% of bindings. | C | 8 |
| 1.3-8 | **Call and type hierarchy** | Incoming and outgoing calls from 1.3-1 (⌃⌥H); C++ and Rust trait hierarchies from the `TypeTable` and catalog (⌃H); both in the side panel. | B | 4 |

Exit: Find Usages on `Counter::record` lists every call and the trait impl; Rename across `shapes.hpp`/`shapes.cpp` applies through the preview; Generate writes a constructor and getters for `geo::Rect`; Extract Function on a selection compiles; a type error appears within two seconds of typing.

## Release 1.4 — Completion that knows types

| # | Feature | Design notes | Tier | Days |
|---|---|---|---|---|
| 1.4-1 | **Expression typing** | `TypeTable` learns the type of a call expression from the callee's return type (buffer, header or catalog signature), of a field access chain, and of an indexed or dereferenced expression, so `foo().bar` and `a.b.c.` complete. Bounded: three hops, then "unknown". | C | 6 |
| 1.4-2 | **Generics and templates** | Rust: substitute the receiver's type arguments into catalog signatures (`Vec<T>::iter` on `Vec<Widget>` yields `Iter<Widget>`); C++: track template arguments of `std::vector<Widget>` and `std::map<K, V>` through `begin()`, `operator[]`, range-for and structured bindings. Header cache skips libc++ `__cxx03/`. | C | 6 |
| 1.4-3 | **Trait methods and overload sets** | Rust receivers offer methods of traits implemented for the type in the catalog (`impl Display for Counter` adds `to_string`), marked with the trait; C++ overloads collapse into one row with an overload count and a signature help that pages through them. | B | 4 |
| 1.4-4 | **Argument-position completion** | Inside a call, rank candidates that fit the parameter type first: enum variants for an enum parameter, constants and locals of the type, `&x` when a reference is expected, a string literal snippet for `&str`. Uses 1.4-1's types and the existing `params` parser. | B | 4 |
| 1.4-5 | **Closures and lambdas** | Parameter types of `|x|` in `iter().map(...)` and `[](auto x)` in `std::for_each` from the callee's signature, so members complete inside the body. | B | 3 |
| 1.4-6 | **Import intelligence** | Group `use` insertions into an existing block by crate, respect `rustfmt` ordering, prefer already-imported paths, and offer the shortest path for a type in scope through a re-export; C++ adds the `#include` that declares a completed type, choosing the header the project already includes elsewhere. | A | 3 |
| 1.4-7 | **Data languages** | TOML values: Cargo dependency versions from the local registry index, feature names of the dependency, `edition` and `resolver` values; CMake: target names, variable names and property keywords in argument position; a `Cargo.toml` hover showing the crate's description. | A | 3 |
| 1.4-8 | **Completion quality gate** | The ranking goldens grow to cover every new site with a top-3 accuracy metric over the two samples and the demo crate; a latency gate keeps p95 under 5 ms per site in CI. | A | 2 |

Exit: `counter.count("ride").` completes `u32` methods; `totals.iter().map(|(name, total)| name.` completes `&str` methods; `shapes[0].` completes `Circle` members in the C++ sample; the goldens report top-3 accuracy above 90%.

## Release 1.5 — Debugging depth and assembly

| # | Feature | Design notes | Tier | Days |
|---|---|---|---|---|
| 1.5-1 | **C and C++ live verification** | A C++ debug self-test on `samples/cpp-demo` (stop in `Circle::area`, expand a `std::vector` local, step out, `cpp_throw` filter) and a C one on `samples/c-demo`; both in CI with developer mode enabled through a setup step; GoogleTest and Catch2 tests run live through binaries built by the sample's CMake. | A | 3 |
| 1.5-2 | **Debug a test** | The gutter marker's menu offers Debug Test: the test binary is built (`cargo test --no-run` parsed for the path, or the CMake test target) and launched under the debugger with the framework's filter argument; the Tests panel marks the debugged test. | B | 4 |
| 1.5-3 | **Attach to process** | Debug ▸ Attach…: a process picker (name, pid, path, filtered to the workspace's binaries first) and `attach` through the existing protocol types; Detach leaves the process running. | B | 3 |
| 1.5-4 | **Watchpoints** | `dataBreakpointInfo` and `setDataBreakpoints` from a variable's context menu (write, read, read/write); shown in the breakpoints list with the address and size; the stop reason names the variable. | B | 3 |
| 1.5-5 | **Memory view** | `readMemory` into a hex pane with ASCII column, address entry, follow-pointer from a variable's context menu, and live refresh on every stop; `writeMemory` behind a confirmation. | B | 4 |
| 1.5-6 | **Assembly support** | Tree-sitter grammar for GNU and Intel syntax (`.s`, `.S`, `.asm`) with highlighting and a label outline; a Disassembly view fed by `disassemble` for the current frame with the source line interleaved, instruction stepping (`granularity: instruction`), and a Registers panel with editing through `setVariable`. Compiler Explorer style: "Show Assembly" for a Rust or C++ function through `cargo rustc -- --emit asm` or `clang -S` into a read-only buffer. | C (view and stepping), A (grammar, Show Assembly) | 8 |
| 1.5-7 | **Core files and crash logs** | Debug ▸ Open Core File… attaches to a core through `coreFile`; a crash log in the run output offers Symbolicate through the debug build's dSYM. | A | 3 |
| 1.5-8 | **Run and build ergonomics** | The CMake profile picker re-detects into `build/<profile>`; GoogleTest and Catch2 binaries appear as `Test` targets with their filters; run configurations support an `.env` file and a "before run" build target; sanitizer runs verified live (ASan report parsed into Problems with the stack). | B | 4 |
| 1.5-9 | **Debugger UX** | Breakpoints panel (enable, disable, remove all, export), thread naming, frame filtering of `std`/`core` frames by default with a toggle, value formatting toggles (hex, decimal, raw), pinning a watch to the gutter as an inline value on the stopped line. | A | 4 |

Exit: a C++ session on `samples/cpp-demo` stops in a method, shows `std::vector` contents, stops on a write watchpoint and shows the memory of the vector's buffer; Debug Test on a Catch2 case stops inside it; Show Assembly on `Counter::record` opens the function's assembly with the source interleaved; a Rust crash's core file opens with the panic frame selected.

## Sequencing

```
1.3-1 references ──► 1.3-2 rename ──► 1.3-6 refactors ──► 1.3-5 intentions
1.3-3 live check ──► 1.3-5 intentions
1.3-7 resolver ──► 1.3-4 generate (base classes, trait items) ──► 1.4-1 expression typing ──► 1.4-2 generics ──► 1.4-3/4/5
1.5-1 C++ live ──► 1.5-2 debug a test ──► 1.5-4 watchpoints ──► 1.5-5 memory
1.5-6 assembly grammar (any time) ──► disassembly view after 1.5-1
```

1.3 stays before 1.4 because usages, rename and generate are what the samples are missing most; 1.4 then builds on the resolver work 1.3-7 forces. 1.5-1 is first in its release because every other debugging item needs the C++ path proven live.

## Tradeoffs and non-goals

- **Heuristic typing over a type checker**: three-hop expression typing, template arguments only for the standard containers, and "unknown" shown honestly. rust-analyzer and clangd stay out.
- **DAP only**: every debugger feature is a `lldb-dap` request; no direct `liblldb` binding, no GDB.
- **Not planned**: coverage and profiler UIs, Valgrind, remote debugging, kernel or embedded targets, macro expansion views, any model in the keystroke path.

## Foundations that already exist (checked 2026-09-14)

The Tier-C items extend subsystems that are already in the tree, which lowers their risk and moves more work into executor-friendly A/B cards:

- **Catalog index** (`src/index/`): a Tantivy index of crate items under `~/Library/Application Support/Ride/index/`, rebuilt by the out-of-process `ride-engine index` batch (the ~50 s reindex). Schema at `schema.rs` (`SCHEMA_VERSION` 12), incremental crate delta at `incremental.rs`. The **reference index (1.3-1) is a new, separate, per-workspace index built in-process on save** — it reuses the Tantivy plumbing and the tree-sitter walk (`src/extract/walk.rs` `extract_tree`/`walk_list`, `emit.rs`), not the catalog schema or the batch indexer.
- **TypeTable** (`src/highlight/{types,rust_types,c_types,type_lookup,c_member_types}.rs`): resolves receivers for member completion today. 1.3-7 and 1.4-1/2 **extend** it (locals/params colouring, expression typing, template args), not build it.
- **Check infra** (`src/check/{clang,clang_project,run,parse,offsets,message,output}.rs`): 1.3-3 live diagnostics is a debounce plus temp-target-dir wrapper over this; the build-diagnostics owner model from 1.2 (`DiagnosticStore` build owner) is reused.

Net: only the reference-index core (1.3-1a), the resolver extension (1.3-7) and Extract Function / Change Signature (1.3-6) are truly architectural. Everything else is Tier A/B.

## Implementation cards — 1.3-1 Reference index and Find Usages

Executor contract is `plan/roadmap/next-impl.md` sections 0–1 (repository rules, project facts, gates, hand-back format). Grok is out of balance, so executors are Claude Opus subagents per card in a git worktree; reviews are Sonnet subagents; the strong model keeps the Tier-C design.

### 1.3-1a References index core — Tier C

**Goal.** A new per-workspace Tantivy index of *references* (name occurrences with their kind and enclosing item), built in-process, updated incrementally when a buffer is saved, queried by byte offset.

**Read first.** `src/index/{schema,incremental,writer,folder,tokenizers,fingerprint,hash}.rs`, `src/index/mod.rs`, `src/engine/mod.rs` (how `Engine` holds the catalog index and sessions), `src/ffi/{query,session}.rs`, `src/highlight/session.rs` (the per-buffer session and its tree).

**Design (fixed).**
- New module `src/refs/` (index only; extractors are 1.3-1b/c). `RefKind { Call, TypeMention, FieldAccess, UsePath, Include, Ident }`, `RefRecord { name, kind, path (workspace-relative file), line, byte_start, byte_end, enclosing_item, enclosing_kind }`.
- `RefIndex`: a Tantivy index under `<support dir>/refs/<sha256 of workspace root>/`, its own small schema (name STRING+fast for exact term lookup, kind, path, line, byte offsets stored, enclosing item stored, a `name_exact` term). One `RefIndex` per workspace root, held on `Engine` behind the existing lock.
- Writer is in-process and incremental: `update_file(path, records)` deletes every document whose `path` equals this file with a `Term` delete, then adds the new records, and commits with a short-lived `IndexWriter` (reuse the `writer.rs` memory-budget pattern). No batch process, no generations.
- Extraction is injected: `RefIndex::update_file` takes `Vec<RefRecord>` produced by a `RefExtractor` trait (`fn extract(lang, text) -> Vec<RefRecord>`); 1.3-1a ships a stub extractor that returns `[]`, so the pipeline is testable before the real extractors land.
- Query: `Engine::find_usages(session_id, cursor_byte) -> UsagesResponse` — resolve the identifier under the caret (reuse `find_definitions`' symbol resolution for the name and whether a reachable definition of that name exists), term-query the ref index for that `name_exact`, return `UsageHit { path, line, byte_start, byte_end, enclosing_item, enclosing_kind, in_definition_scope: bool }` grouped by file, with hits whose enclosing scope can reach the definition marked `in_definition_scope` (ranked first) and the rest as "other matches". FFI records in `src/ffi/refs.rs`.
- `Engine` gains `note_saved(session_id)` (or reuses an existing save hook) that re-extracts and calls `update_file`.

**Steps.** Create `src/refs/{mod,index,record,query}.rs` and `src/ffi/refs.rs`; wire `mod refs;` in `lib.rs` and the FFI re-exports; add `find_usages` and the save hook on `Engine`; `bash scripts/build-engine.sh` to regenerate bindings.

**Acceptance.** `tests/refs.rs`: with a hand-built `Vec<RefRecord>` for `samples/rust-demo` (two calls to `record`, one to `count`), `update_file` then `find_usages` at the caret on `record` returns both call sites grouped under `src/main.rs`, and a second `update_file` for the same file replaces rather than duplicates. Latency: updating one file under 50 ms in the test. Out of scope: the real extractors (1.3-1b/c), the app UI (1.3-1d), code vision.

### 1.3-1b Rust reference extractor — Tier A, after 1.3-1a

`src/refs/rust.rs`: a tree-sitter walk of a Rust buffer producing `RefRecord`s — `call_expression` and `method_call` names (Call), type identifiers in type positions (TypeMention), `field_expression` field names (FieldAccess), `use` path segments (UsePath), every other identifier (Ident) — each tagged with its enclosing item name and kind from the outline. Reuse the query/walk patterns in `src/extract/` and `src/highlight/`. Tests in `tests/refs.rs` on `samples/rust-demo`: `record` yields two Call records at the right lines with enclosing item `main`; `Counter` yields TypeMention records. Wire it as the `RefExtractor` for `Lang::Rust`.

### 1.3-1c C and C++ reference extractor — Tier A, after 1.3-1a

`src/refs/c.rs`: the same for C and C++ (call expressions, type identifiers, field accesses through `.`/`->`, `#include` targets). Tests on `samples/cpp-demo`: a call to a method declared in `include/shapes.hpp` yields a Call record. Wire it for `Lang::C`/`Lang::Cpp`.

### 1.3-1d Find Usages panel, indexing hook and code vision — Tier B, after 1.3-1b/c

Indexing hook first (the engine has `find_usages` and `note_saved` but nothing calls the latter, so the index is empty): call `note_saved(session)` off the main thread whenever a buffer is opened and whenever it is saved (through the existing `SessionService`/`didSave` path), and index every already-open buffer once when a workspace finishes opening. Then the panel: `app/Ride/Usages/UsagesPanel.swift` (a bottom-panel tab or a side panel listing `UsageHit`s grouped by file with the enclosing item, click to open at the byte, "other matches" section collapsed), `⌥F7` in the Navigate menu through `MenuModel`, and a dimmed "N usages" code-vision line above each outline item drawn as an editor overlay (a pure `UsageVision.swift` in RideTests maps outline items plus counts to line positions). The query runs off the main thread with the stop-generation pattern from the debug panel. Self-test step on `samples/rust-demo`: ⌥F7 on `record` lists two usages. Out of scope: rename (1.3-2), hierarchy (1.3-8).

### 1.3-1e Code-vision "N usages" line — Tier B, deferred

1.3-1d shipped the pure `UsageVision` model (outline items + counts → line labels) but did not render the dimmed "N usages" line above each item, because it needs `RideTextView` line-fragment work. Render it: an editor overlay (a top inset or a line-fragment padding above each outline item's first line) drawing a dimmed, clickable "N usages" label from `UsageVision`; the count comes from a background `find_usages`-style aggregate keyed by item, refreshed on save; clicking opens the Find Usages panel filtered to that item. Not on the rename path, so it can wait until after 1.3-2. Acceptance: a self-test asserts the vision model yields the right line/label for `record`; a manual check by the reviewer for the drawn overlay.

## Implementation cards — 1.3-2 Rename

### 1.3-2a Rename engine — Tier B, after 1.3-1

**Goal.** `Engine::rename_local(session_id, cursor_byte, new_name) -> Vec<TextEdit>` renaming every in-scope occurrence of a local/parameter through the existing scope analysis, and `Engine::rename_plan(session_id, cursor_byte, new_name) -> RenamePlan { files: [RenameFile { path, edits: [TextEdit] }], skipped: [String] }` for a workspace symbol built from the reference index: only occurrences whose `in_definition_scope` is true are edited; other same-name matches go to `skipped` (shown, not applied). A `.h`/`.cpp` pair is one plan (both files' hits). Refuse (empty result) when the caret is not on a renameable identifier or the new name is not a valid identifier for the language.

**Read first.** `src/highlight/{scope,rust_locals,c_locals}.rs` (scope/occurrence analysis), `src/engine/refs.rs` (find_usages), `src/refs/`, `src/engine/edits.rs` and the `TextEdit` FFI record, `src/ffi/`.

**Steps.** `src/engine/rename.rs` with the two methods and a pure `plan_from_usages` helper; `RenamePlan`/`RenameFile` records in `src/ffi/rename.rs`; `bash scripts/build-engine.sh`. Tests in `tests/rename.rs`: renaming the `counter` local in `samples/rust-demo` main yields edits at every occurrence and none outside the fn; a workspace rename of `record` produces a plan covering `src/main.rs` and `src/util.rs`; an invalid new name yields an empty result; a workspace symbol the index cannot resolve to a definition yields an empty `files` and all occurrences in `skipped` (never auto-edited). Out of scope: the app UI (1.3-2b).

### 1.3-2b Rename UI — Tier B, after 1.3-2a

**Goal.** ⇧F6: an inline rename box over the identifier for a local (apply `rename_local` as one undo group on commit, Esc cancels); for a workspace symbol, a preview sheet listing the `RenamePlan` files with their edits, ticked by default, and a separate "Review — could not verify these are the same symbol" section built from `skipped`, unticked by default, with per-file and select-all toggles; when `files` is empty (the engine could not resolve the symbol) show a banner saying no occurrence was verified and nothing will change until the user ticks. Apply writes only ticked occurrences, through open `Buffers` or to disk then triggering the watcher. `.h`/`.cpp` pairs shown together. Menu item through `MenuModel`; check ⇧F6 against existing bindings. Self-test on `samples/rust-demo`: rename the `counter` local to `tally`, assert the occurrences changed and nothing outside `main`; a workspace rename preview of `record` lists two files. Out of scope: rename of a field/method across the catalog (heuristic-limited; refuse rather than guess).

### 1.3-2c Applyable review occurrences and safe apply — Tier B, after 1.3-2b

Two problems: the workspace apply can corrupt files, and review occurrences cannot be applied. (A) **Data safety (must):** `RenameApply.fileEdit` writes the plan's byte offsets onto a file's current text with only a bounds check. The reference index refreshes on buffer open and save, not on every edit, so a file edited since its last index has stale offsets and Apply can overwrite the wrong bytes and discard the user's unsaved edits with no undo. Fix: before applying, re-validate every edit against the live text — the substring at each edit's range must equal the plan's old `name`; if any edit in a file does not match, skip that whole file and report it in the result ("N files skipped — changed since indexing"). Apply to an open buffer through the editor's `replaceText`/undo path (one undo group), not a raw text overwrite, so the engine session and undo stay in sync; only closed files are written to disk directly. (B) **Applyable review:** 1.3-2a returns `skipped` as a list of "path:line" strings, so 1.3-2b can only display the review occurrences, not apply them: a workspace rename of a symbol the index cannot resolve (everything in skipped) can change nothing even when the user confirms. Fix the flow end to end. Engine: `RenamePlan` gains a `review` list of the same `{ path, edits }` shape as `files`, replacing the string `skipped`; `plan_from_usages` routes in-definition-scope hits to `files` and every other same-name hit to `review` with its byte-range edit. App: the preview sheet's Review rows carry those edits, unticked by default, and Apply writes the ticked review occurrences alongside the ticked verified files through the same `RenameApply` path; the banner still warns when `files` is empty. Update `tests/rename.rs` (the unresolved `record` case now populates `review` with edits covering both files, `files` empty) and `RenameSelectionTests`. Self-test: after opening the workspace-rename preview of `record`, tick a review file and Apply, then assert that file changed; a second step edits an open buffer after indexing and asserts Apply skips it rather than corrupting it. Engine build is needed (the RenamePlan record changes), then the xcodebuild build+test gate and a self-test EXIT 0. Keep the safety default: review rows start unticked, so nothing an unverified rename touches is applied without an explicit tick.

### 1.3-2d Self-test reference-index isolation — Tier A

The Find Usages and rename self-test steps depend on the per-workspace reference index at the support directory's `refs/<sha256 of canonical root>/`, which persists across runs, so repeated runs on the same demo path accumulate state and the find-usages step becomes order-dependent (flagged in 1.3-1d and 1.3-2b). Make the demo self-test deterministic: when `DemoLaunch.isDemo`, point the reference index at a fresh temp directory per launch, or clear the workspace's refs directory on scene startup. CI already uses a fresh copy per run; this only hardens local repeat runs. Acceptance: running the rust self-test twice in a row on the same `--open` path both report `EXIT 0` with the find-usages and rename steps passing.
