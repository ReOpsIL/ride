# Documentation index

| Topic | Where |
|---|---|
| Product and architecture spec | `plan/ride_draft.md` |
| Roadmap and phases | `plan/roadmap/improve-extend.md` |
| UI design plan and audit | `plan/roadmap/ui-design.md` |
| Historical engine notes | `plan/autocomplete.md` |
| Engine follow-ups | `todo/engine/remaining.md` |
| App follow-ups | `todo/app/remaining.md` |

## Engine layout

| Module | Responsibility |
|---|---|
| `src/discover` | `$CARGO_HOME` registry and git checkouts, rustc sysroot, `cargo metadata` |
| `src/extract` | tree-sitter item extraction with module paths, impls, re-exports |
| `src/markdown` | pulldown-cmark HTML rendering with token spans for Rust, C and C++ fences |
| `src/index` | Tantivy schema, one-shot writer, generations, manifest, status and warnings logs |
| `src/query` | prefix / BM25 completion search, crate prefix, keyword hits |
| `src/highlight` | buffer sessions over a `Syntax` trait: a generic tree-sitter `TreeSyntax` driven by a per-language `Grammar` (Rust, C, C++ under `grammar/`, queries under `queries/<lang>/`) and Markdown (tree-sitter-md block + inline, code fences re-parsed per language); highlight deltas, outline, parse errors |
| `src/check` | `cargo check` JSON diagnostics, `clang -fsyntax-only` diagnostics driven by `compile_commands.json`, rustfmt and clang-format |
| `src/engine` | in-process `Engine`: sessions, query routing, definitions, tools, manifest watch |
| `src/ffi` | UniFFI records, enums and listener traits |

## Languages

| Language | Extensions | Highlight | Outline | Completion | Definitions | Format |
|---|---|---|---|---|---|---|
| Rust | `rs` | tree-sitter-rust | `extract` items | keywords, buffer locals, crate catalog | buffer outline + catalog | rustfmt |
| C | `c`, `h` | tree-sitter-c | functions, prototypes, structs/enums/unions, typedefs, globals, `#define` | keywords, buffer locals, included headers, struct members after `.` / `->` | buffer outline + included headers | clang-format |
| C++ | `cpp`, `cc`, `cxx`, `c++`, `hpp`, `hh`, `hxx`, `h++`, `inl`, `ipp`, `tpp`, `cppm`, `ixx` | tree-sitter-cpp (C query + C++ additions) | C items plus classes, methods, namespaces, `using` aliases, concepts | keywords, buffer locals, included headers, class members after `.` / `->` / `this->` (bases followed) | buffer outline + included headers, `a::b::c` qualifier | clang-format |
| Markdown | `md`, `markdown` | tree-sitter-md | headings | none | none | none |

Non-Rust sessions never touch the crate index: the engine forces `BufferLocal` mode for their completion queries and skips the catalog in `find_definitions`. `.h` opens as C unless the first 64 KB contain a C++ marker (`namespace`, `class`, `template`, `using`, an access specifier, `extern "C++"`, or an `#include <name>` without a dot), in which case it opens as C++. `SessionOpen.lang` carries the language the engine chose so the app can relabel a sniffed header.

### C / C++ headers

A C/C++ session keeps its file path and the include directories from its `compile_commands.json` entry (`-I`, `-iquote`, `-isystem`, resolved against the entry's `directory`). Its `#include` lines (quoted ones relative to the including file first, then the include directories; angled ones only from the include directories) are followed transitively through an engine-wide header cache (`engine/headers.rs`, keyed by path and mtime, at most 64 files per lookup, files over 4 MB skipped). Each cached header holds its outline, its own includes and a `TypeTable`. Definitions of a symbol found in a reachable header come back with `source_path`, and their outline items join buffer-local completion below buffer definitions but above plain identifier mentions. System headers are only reached when an include directory contains them; there is no sysroot probe.

### C / C++ member access

When the text before the completion prefix ends in `.` or `->` (the grammar's `member_ops`; Rust only has `.`), the engine switches the query to `MemberAccess` (no keywords) and tries to type the receiver: a plain identifier is looked up among the buffer's declarations (nearest one before the caret wins), `this` resolves to the enclosing class or, for an out-of-class `T::f()` body, the qualifier `T`. The type name is resolved through the buffer's and the reachable headers' `TypeTable`s: `typedef` and `using` aliases are followed, anonymous `typedef struct { … } name` bodies are registered under the alias, and C++ base classes are walked (depth 6). Members are reported as `Field` or `Method` with the declaring line as jump target. When the receiver cannot be typed (a call result, a field chain), the fallback lists the buffer's `field_identifier` names and outline methods instead of every identifier.

`samples/c-demo` and `samples/cpp-demo` are small projects covering all of this; `tests/samples.rs` drives them through the engine, so they double as fixtures. A `compile_commands.json` `directory` may be relative; it is resolved against the database's own directory, which is how the samples ship a working `build/compile_commands.json`.

### C / C++ diagnostics

`run_check_c` runs `clang -fsyntax-only` on one saved file and parses the `path:line:col:{ranges}: level: message [-Wflag]` lines into the same `Diagnostic` record `cargo check` produces, with byte offsets computed from the file on disk. Flags come from the nearest `compile_commands.json` (searched upward from the file in `.`, `build/`, `out/` and `cmake-build-debug/`): the entry for the file, or for a source in the same directory when the file is a header (a source of the same language is preferred; borrowing a sibling of the other language also drops its `-std=` flag), with the compiler, `-c`, `-o` and dependency-file flags stripped. Without a database the fallback is `-std=c23` / `-std=c++23 -Wall -I<file dir>`. The app runs it on save and on Check (⌘B) for C/C++ buffers instead of `cargo check`, and keeps the diagnostics of each source (cargo or file path) separately in the Problems panel.

Format on save for C/C++ runs only when `has_tool("clang-format")` is true, so a machine without clang-format saves silently.

## Index directory

```
manifest.json     schema_version, engine_semver, generation, live_dir, fingerprint, docs
gen-N/            live Tantivy index (previous generation is kept, older ones pruned)
staging-<pid>/    in-progress write, renamed to gen-N on success
status.jsonl      progress lines: state, docs, crates_done/total, warnings
warnings.jsonl    per-crate extraction errors of the last run
```

A run whose crate-set fingerprint matches `manifest.json` appends a `ready` status and writes nothing. `ride-engine index --force` or the app's Reindex menu bypasses the check.

## Engine surface used by the app

| Method | Purpose |
|---|---|
| `query_completions` | prefix / crate / phrase completions with context bias, best hit per name |
| `find_definitions` | identifier under the caret to buffer outline or index definitions |
| `run_check` | `cargo check` diagnostics with absolute paths and byte ranges |
| `format_rust` | rustfmt a buffer |
| `run_check_c` | `clang -fsyntax-only` diagnostics for one C or C++ file, flags from `compile_commands.json` |
| `has_tool` | whether a toolchain binary (`clang-format`, …) is on PATH or in the usual install dirs |
| `format_c` | clang-format a C or C++ buffer (`--assume-filename` from the buffer path so `.clang-format` is honoured) |
| `render_markdown` | markdown to HTML with line anchors and highlighted Rust, C and C++ fences, for the preview pane |
| `open_session` / `apply_edit` / `set_visible_range` | highlight deltas, outline, parse errors; the language comes from the path and, for `.h`, the content (`Lang::for_buffer`) and is returned in `SessionOpen.lang` |

## Release

`scripts/release.sh` builds the engine, archives Ride.app in Release, signs it
(ad hoc unless `RIDE_SIGN_IDENTITY` is set), zips it under `target/release-app/`
and, when `RIDE_NOTARY_PROFILE` names a notarytool keychain profile, notarizes
and staples.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/build-engine.sh` | release engine for arm64, UniFFI Swift bindings, xcframework, `ride-engine` helper |
| `scripts/run.sh [folder]` | Debug build of Ride.app and open a folder |
| `scripts/install.sh [dest]` | check Xcode/rustup/rust-src, build engine and Release app, ad-hoc sign, install to /Applications |
| `scripts/release.sh` | Release archive, sign, zip, optional notarize |
| `scripts/make-icon.swift <out-dir>` | render the app icon set (`swiftc -O` it, run, then `iconutil -c icns`) |

## Screenshot review without input

`Ride.app --args --open <folder> --demo <scene> --frame 1440x900` drives the UI into a state (`editor`, `completion`, `hover`, `quickopen`, `symbols`, `find`, `problems`, `outline`, `light`) so it can be captured by window id. Scenes never write preferences or files.
