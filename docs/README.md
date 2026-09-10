# Documentation index

| Topic | Where |
|---|---|
| Product and architecture spec | `plan/ride_draft.md` |
| Roadmap and phases | `plan/roadmap/improve-extend.md` |
| UI design plan and audit | `plan/roadmap/ui-design.md` |
| Completion plan (sites, `use`/`#include`, ranking, rows, accept) | `plan/roadmap/completion.md` |
| Historical engine notes | `plan/autocomplete.md` |
| Engine follow-ups | `todo/engine/remaining.md` |
| App follow-ups | `todo/app/remaining.md` |

## Engine layout

| Module | Responsibility |
|---|---|
| `src/discover` | `$CARGO_HOME` registry and git checkouts, rustc sysroot, `cargo metadata`, clang system include directories |
| `src/includes` | `#include` path completion over the including file's directory, compile-database and system include directories |
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
| TOML | `toml` | tree-sitter-toml-ng | tables and table arrays | Cargo manifest table and key names, keys in the buffer | buffer outline | none |
| Makefile | `Makefile`, `GNUmakefile`, `mk`, `mak`, `make` | tree-sitter-make | targets, variable and `define` assignments | GNU make directives, functions, builtin variables and special targets, buffer targets and variables | buffer outline | none |
| CMake | `CMakeLists.txt`, `cmake` | tree-sitter-cmake | project, `add_executable` / `add_library` / `add_custom_target` targets, `set` variables, `option`s, functions, macros | common commands, variables and argument keywords, buffer functions, targets and variables | buffer outline | none |
| Markdown | `md`, `markdown` | tree-sitter-md | headings | none | none | none |

`Lang::for_path` checks the file name before the extension (`Makefile`, `GNUmakefile`, `CMakeLists.txt`). A buffer item whose name equals a keyword wins the name dedupe, so `[dependencies]` completes as the buffer's table rather than the manifest keyword. Non-Rust sessions never touch the crate index: the engine forces `BufferLocal` mode for their completion queries and skips the catalog in `find_definitions`. `.h` opens as C unless the first 64 KB contain a C++ marker (`namespace`, `class`, `template`, `using`, an access specifier, `extern "C++"`, or an `#include <name>` without a dot), in which case it opens as C++. `SessionOpen.lang` carries the language the engine chose so the app can relabel a sniffed header.

### C / C++ headers

A C/C++ session keeps its file path and the include directories from its `compile_commands.json` entry (`-I`, `-iquote`, `-isystem`, resolved against the entry's `directory`). Its `#include` lines (quoted ones relative to the including file first, then the include directories, then the compiler's system directories; angled ones from the include directories and then the system directories) are followed transitively through an engine-wide header cache (`engine/headers.rs`, keyed by path and mtime, files over 4 MB skipped). The system directories are the `clang -E -v` probe of `discover::system_includes` (framework directories excluded). A lookup follows at most 64 project headers plus 512 headers under system directories, breadth first from the including file. Each cached header holds its outline, its own includes and a `TypeTable`. Definitions of a symbol found in a reachable header come back with `source_path`, and their outline items join buffer-local completion below buffer definitions but above plain identifier mentions; reserved names (`__x`, `_X`) from headers stay hidden until the typed prefix starts with `_`.

Headers under a system directory are summarized differently (`engine/headers.rs::load_system`): the text first goes through `highlight/scrub.rs`, a length-preserving pass that blanks all-caps reserved macros (`_LIBCPP_HIDE_FROM_ABI`, `__API_AVAILABLE(...)`, an attribute-like `__printflike(1, 2)` after a declarator), rewrites `_LIBCPP_BEGIN_NAMESPACE_STD` / `_LIBCPP_END_NAMESPACE_STD` to `namespace std {` / `}`, and drops preprocessor conditionals that sit inside a declaration (keeping the last branch), so libc++ and the SDK's C headers parse instead of collapsing into one `ERROR` node. Extension-less files (`vector`, `string`) are parsed as C++. The resulting `FileSummary` is persisted as JSON under `<index_dir>/headers/<hash>.json`, keyed by a hash of path, mtime and size, so a second project open reads the summaries instead of re-parsing the SDK; `TypeTable`, `OutlineItem` and `IncludeRef` serialize for that. Both branches of an `#if` are followed, so libc++'s frozen `__cxx03/` copies compete for the 512 budget.

Per-keystroke work is cached at two levels. A `BufferSession` keeps its `SourceScope` (path, include dirs, includes, `TypeTable`) behind `highlight/scope.rs::ScopeCache`, rebuilt only when the text or location changed. The engine keeps the resolved header list per session in `engine/reach.rs`: `Reach::take` runs under the engine lock and reuses the cached list when the session's includes are unchanged and every project header still loads to the same cached `Arc` (an mtime change or a deleted file invalidates it; system headers are assumed stable); a miss resolves the graph outside the lock and `remember` stores it after the query.

#### Include completion

`includes::complete` turns an `IncludeRequest` (quoted or angled, the text typed after the delimiter, the including file, the compile-database search dirs and the ranked system dirs) into `CompletionHit`s by listing directories only. The typed text splits at its last `/` into a sub-directory and a prefix; the sub-directory is listed under each root in order (quoted: the including file's directory, then the search dirs, then system dirs; angled: search dirs, then system dirs) and the first root to supply a name wins. Only header-like files (`h hh hpp hxx h++ inl ipp tpp inc` or no extension, so libc++ `vector` appears) and directories are listed; dotfiles are dropped and `__*` names stay hidden until the prefix starts with `_`. Directory rows are `ItemKind::Mod` and end in `/` so accepting one re-triggers; file rows are `ItemKind::Header` and insert the bare name, the caller closes the delimiter. `signature` carries the root directory and `source_path` the absolute path. Scores are tiered: including-file directory 900, search dirs 800, system dirs 700, framework dirs 600, with files 10 above directories, shorter names first and an exact name match +100. Framework directories (`Foo.framework/Headers/X.h`) complete as `Foo/` and then `Foo/X.h`. Listings are cached process-wide by directory and mtime, at most 4000 entries each.

The system directories come from `discover::system_includes::SystemIncludes`, which runs `clang -E -x <c|c++> - -v` once per (language, extra args) and parses the `#include <...> search starts here:` block; framework directories are flagged and sorted last, and a failed probe caches an empty list. `probe_args` keeps only the `-isysroot`, `--sysroot`, `-target` / `--target` and `-stdlib` flags of a compile-database entry so the probe sees the entry's SDK without its warnings and defines.

### C / C++ member access

When the text before the completion prefix ends in `.` or `->` (the grammar's `member_ops`; Rust only has `.`), the engine switches the query to `MemberAccess` (no keywords) and turns the receiver expression into a `Chain` (`highlight/members.rs`): the node ending at the operator is widened to the largest expression ending there, and `highlight/c_members.rs` reads it into a root plus at most eight steps. Roots: a plain identifier's declared type (nearest declaration before the caret, parameters, fields and range-for variables included), `this` (the enclosing class or, for an out-of-class `T::f()` body, the qualifier `T`), a free-function call `f()` (its declared return type), `T::f()` (a static call), `(T)x`, `static_cast<T>(x)`, `T{...}` and `new T`. An `auto` local takes the chain of its initializer. Steps are field accesses and method calls; `a[i]`, `*p` and parentheses are transparent. The engine (`engine/access.rs`) follows the chain through the buffer's and the reachable headers' `TypeTable`s, which store each member's declared type or return type next to the member (`TypeTable::follow`): `typedef` and `using` aliases are followed, anonymous `typedef struct { … } name` bodies are registered under the alias, and C++ base classes are walked (depth 6). Members are reported as `Field` or `Method` with the declaring line as jump target. When a chain does not resolve (range-for over a template, an iterator, an unknown function), the fallback lists the buffer's `field_identifier` names and outline methods instead of every identifier.

A C++ `::` site (`Site::ScopedPath`) is served from the same tables (`engine/paths.rs::scoped_hits` → `TypeTable::scoped`). The `TypeTable` records namespace membership: `namespace geo { … }` registers its direct items under `geo` (functions, statics, classes, typedefs, concepts, nested namespaces as `Namespace` items), `geo::detail` registers under `geo::detail` and as `detail` inside `geo`, inline and anonymous namespaces are flattened into their parent, and `enum` bodies register their enumerators as `Variant` members of the enum. A path is looked up as a namespace first; otherwise its last segment is resolved as a type (so `geo::Registry::` lists the class members, `T::Kind::` the enumerators); a leading type or namespace alias (`using Fig = geo::Shape;`, `namespace fs = std::filesystem;`) is substituted first and `using namespace` is ignored. `std::` works when the libc++ headers are reachable, with reserved names filtered as above. Results keep declaration order.

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

### Schema v11 fields

Besides the stored text fields (`path`, `name`, `signature`, `doc_first_paragraph`, `visibility`, `source_path`, ...) and the ranking fast fields (`scope_rank`, `kind_rank`, `name_len`, `name_hash`, `path_len`, `has_doc`), schema 11 adds the fields the completion plan's sites and ranking read. Field names are exported as constants (`PARENT_PATH`, `NAME_HUMP`, `REACHABLE`, `DEPRECATED`) next to `parent_path_of` and `hump`.

| Field | Type | Value |
|---|---|---|
| `parent_path` | STRING, stored | the item's `path` minus its last `::` segment, lowercased like `path_exact`; empty for crate docs and crate-root items; `type` for a `Type::method` doc. A term query lists the direct children of a path (`use std::collections::`, `HashMap::`). |
| `name_hump` | TEXT, edge-ngram tokenizer | the name's hump string: the first letter of every word, lowercased, words split on `_`, lower→upper and letter→digit (`HashMap` → `hm`, `read_line` → `rl`, `Utf8Error` → `ue`). Only indexed when at least two characters long. |
| `reachable` | u64 fast | 1 for every workspace doc; otherwise 1 only when the item is `pub` and every enclosing module on its declaring path is `pub`, or the doc was emitted for a `pub use` at such a path. Methods and variants inherit the flag of their type, trait or enum (`extract/reach.rs`). Pub items under private modules stay indexed with 0 so go-to-definition still finds them. |
| `deprecated` | u64 fast | 1 when the item carries `#[deprecated]` or `#[deprecated(...)]`. |

Two extraction changes ship with the bump: enum variants are emitted as `variant` docs at `Enum::Variant` (signature `Some(T)`, `Named { .. }`, `Unit`; doc, visibility and reachability from the enum), and nothing inside a `#[cfg(test)]` module or carrying `#[cfg(test)]` / `#[test]` is emitted in any scope (a `#[cfg(test)] mod tests;` file is also excluded from the leftover-file scan).

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
