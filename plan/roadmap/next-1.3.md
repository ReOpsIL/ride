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
