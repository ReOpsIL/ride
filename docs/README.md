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
| `src/query` | prefix / hump / BM25 catalog search, path children and crate listings, keyword hits, best-per-name collector with the reachability filter |
| `src/score` | shared score tiers and bonuses used by buffer, header and catalog hits |
| `src/params` | parameter-list parsing of signatures for call snippets and signature help |
| `src/text` | shared text helpers: first sentence, whitespace collapse, caps |
| `src/highlight` | buffer sessions over a `Syntax` trait: a generic tree-sitter `TreeSyntax` driven by a per-language `Grammar` (Rust, C, C++ under `grammar/`, queries under `queries/<lang>/`) and Markdown (tree-sitter-md block + inline, code fences re-parsed per language); highlight deltas, outline (with signature and doc), parse errors, completion sites (`site/`), imports, call sites, Rust/C type tables and receiver typing, postfix receivers |
| `src/check` | `cargo check` JSON diagnostics, `clang -fsyntax-only` diagnostics driven by `compile_commands.json`, rustfmt and clang-format |
| `src/engine` | in-process `Engine`: sessions, the completion router (`query.rs`) and its per-site sources (`identifier`, `access`, `rust_members`, `paths`, `includes`, `lists`, `postfix`, `snippets`, `merge`), definitions, import edits, signature help, tools, manifest watch |
| `src/ffi` | UniFFI records, enums and listener traits |

## Languages

| Language | Extensions | Highlight | Outline | Completion | Definitions | Format |
|---|---|---|---|---|---|---|
| Rust | `rs` | tree-sitter-rust | `extract` items | keywords and keyword snippets, buffer locals, crate catalog, `use` paths (crates, then children), `Type::` / `module::` children, typed members after `.` (buffer types + catalog), struct-literal fields, `#[derive(…)]` and attribute names, postfix templates after `.`, call snippets, auto-import edits | buffer outline + catalog | rustfmt |
| C | `c`, `h` | tree-sitter-c | functions, prototypes, structs/enums/unions, typedefs, globals, `#define` | keywords and snippets, buffer locals, included headers, struct members after `.` / `->`, `#include <…>` / `"…"` header paths, `#` directives | buffer outline + included headers | clang-format |
| C++ | `cpp`, `cc`, `cxx`, `c++`, `hpp`, `hh`, `hxx`, `h++`, `inl`, `ipp`, `tpp`, `cppm`, `ixx` | tree-sitter-cpp (C query + C++ additions) | C items plus classes, methods, namespaces, `using` aliases, concepts | keywords and snippets, buffer locals, included headers, class members after `.` / `->` / `this->` (bases followed), `#include` header paths, `#` directives | buffer outline + included headers, `a::b::c` qualifier | clang-format |
| TOML | `toml` | tree-sitter-toml-ng | tables and table arrays | Cargo manifest table and key names, keys in the buffer | buffer outline | none |
| Makefile | `Makefile`, `GNUmakefile`, `mk`, `mak`, `make` | tree-sitter-make | targets, variable and `define` assignments | GNU make directives, functions, builtin variables and special targets, buffer targets and variables | buffer outline | none |
| CMake | `CMakeLists.txt`, `cmake` | tree-sitter-cmake | project, `add_executable` / `add_library` / `add_custom_target` targets, `set` variables, `option`s, functions, macros | common commands, variables and argument keywords, buffer functions, targets and variables | buffer outline | none |
| Markdown | `md`, `markdown` | tree-sitter-md | headings | none | none | none |

`Lang::for_path` checks the file name before the extension (`Makefile`, `GNUmakefile`, `CMakeLists.txt`). A buffer item whose name equals a keyword wins the name dedupe, so `[dependencies]` completes as the buffer's table rather than the manifest keyword. Non-Rust sessions never touch the crate index (`Lang::has_catalog`), and `find_definitions` skips it for them. `.h` opens as C unless the first 64 KB contain a C++ marker (`namespace`, `class`, `template`, `using`, an access specifier, `extern "C++"`, or an `#include <name>` without a dot), in which case it opens as C++. `SessionOpen.lang` carries the language the engine chose so the app can relabel a sniffed header.

### Completion sites and pipeline

The engine classifies the caret itself (`highlight/site/`, one classifier per grammar, text scan with tree-sitter used for comment/string vetoes and struct literals) and ignores the app's `prefix` / `mode` / `context` whenever a session exists; `CompletionResponse` carries the `site` kind and `replace_start_byte` (UTF-8) so the app replaces exactly the typed prefix. Sites and what answers them:

| Site | Trigger | Source (`engine/`) |
|---|---|---|
| `Identifier` | a word, or a manual trigger | `identifier.rs`: declared locals (`TIER_DECLARED`), buffer items (`TIER_ITEM`), reachable header items (`TIER_HEADER`), identifier mentions (`TIER_MENTION`), keywords, and for Rust the catalog from two characters on (imported names +`IMPORT_BONUS`, prelude names +`PRELUDE_BONUS`, typed-case agreement +`CASE_BONUS`) |
| `MemberAccess` | `.` / `->` | `access.rs`: typed receiver members in declaration order, else the field-name fallback; Rust adds postfix templates (`postfix.rs`: `if`, `match`, `while`, `let`, `not`, `ref`, `refm`, `dbg`, `return`, `some`, `ok`, `err`, `box`, `println`) whose `replace_start_byte` points at the receiver expression |
| `UsePath` | inside `use …;` (brace groups followed) | `paths.rs`: no segment → every crate in the catalog plus `crate`/`self`/`super`/`std`/`core`/`alloc`; segments → direct children through the `parent_path` field (`crate::` maps to the workspace package, `self`/`super` to the file's module path) plus `self` and `*`; methods are dropped |
| `ScopedPath` | `a::b::` outside `use` | `paths.rs`: children of the path; a capitalised last segment ranks methods first |
| `Include` | `#include <…` / `"…` | `includes.rs` over `crate::includes` with the compile-database dirs and the cached `clang -E -v` system dirs |
| `Directive` | `#…` on a preprocessor line | `lists.rs` |
| `Attribute` | inside `#[…]` / `#![…]` | `lists.rs`: attribute names, or inside `derive(` the std derives plus catalog derive macros (`#[proc_macro_derive(Name)]` fns are indexed as `Name`) |
| `StructLiteral` | inside `Foo { … }` | `access.rs` |
| `None` | comments, strings, after a closed include | nothing |

All sources go through `merge::finish`: one scorer (`src/score.rs` tiers plus the catalog formula in `query/rank.rs`), a dedupe by name in which a bare identifier mention or keyword yields to any real item of the same name, then the limit. Catalog prefix queries also match the `name_hump` field (`HM` → `HashMap`, demoted by `HUMP_PENALTY`) and skip docs with `reachable = 0`; deprecated docs lose `DEPRECATED_PENALTY`. Fn/method hits whose signature parses become call snippets (`name(${1:a}, ${2:b})$0`, `snippet = true`), macros `name!($0)`, and statement keywords expand to templates indented like the caret line (`snippets.rs`). Catalog items not imported and not in the prelude carry `import_path`; `Engine::import_edit` turns it into a sorted `use` insertion in the buffer's last import block (or after the inner attributes). `Engine::signature_help` finds the enclosing call by a text scan (`highlight/call_site.rs`), resolves the callee through the buffer outline, reachable headers and the catalog, and returns the signature with parameter byte ranges and the active index.

`ride-engine complete <file> [--byte N | --find <anchor>] [--typed <text>] [--repeat N]` opens a session on a file and prints the site, replace offset and hits, so any of the above can be probed without the app.

### Rows

Buffer and header hits carry what the outline knows about the item. `OutlineItem.signature` is the declaration without its body: for Rust the extractor's signature (`pub fn new() -> Self`), for C and C++ the source from the item start up to the body, initializer or `;` with whitespace collapsed and capped at 160 characters (`int shape_sides(const shape_t *s)`, `#define SQUARE(x)`, `class Circle : public Shape`), for TOML, Make and CMake the item's first source line. `OutlineItem.doc` is the comment block directly above the item: for Rust the first `///` / `/** */` paragraph, for C and C++ consecutive `//` lines or one `/* */` block with the markers, leading `*` and Doxygen `@brief` stripped, capped at 400 characters (a `template<…>` head or a `typedef` wrapper is looked through); TOML, Make and CMake have none. `CompletionHit.from_outline` copies both into `signature`, `doc_first_sentence` and `doc_paragraph` for buffer outline items, header items and definitions. `CompletionHit.detail` carries the declared type of a local when it is written in the source (`u32` for `let n: u32` or a Rust parameter, `const char *` for a C declaration or parameter, `const Circle &` for a C++ reference parameter; no inference) and of a struct or class field reached through `.` / `->`; items from a reachable header put the header file name (`shapes.h`) there instead.

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

Member lists keep declaration order, with constructors, destructors and `operator` overloads moved to the end. `find_definitions` on an `#include` line answers with the resolved header as a `Header` hit (`source_path` set), so the app can open it.

### Rust member access

For a Rust `.` site the receiver node (`identifier`, `field_identifier` or `self`) is typed by `highlight/rust_receiver.rs` and its members come from `engine/rust_members.rs`. `self` resolves to the enclosing `impl` block's type (`impl<T> Foo<T>` → `Foo`, `impl Trait for Bar` → `Bar`). An identifier resolves through its nearest declaration before the caret (a declaration whose block or function encloses the caret is preferred over an earlier one elsewhere): an annotation on a `let`, fn parameter or typed closure parameter, or otherwise the initializer of a `let`: `T::assoc(..)` and `T { .. }` give `T` (only when `T` starts with an uppercase letter), `vec![..]` gives `Vec`, `format!(..)`, `String::new()` and `.to_string()` / `.to_uppercase()` / `.to_lowercase()` give `String`, string literals give `str`, integer and float literals `i32` / `f64`, `x as T` gives `T`. A field receiver (`self.origin.`, `r.origin.`) follows the declared type of the field in a buffer `struct` or `union` (chains up to four deep). Type names strip references, lifetimes and generics to the base name (`&'a mut Vec<u8>` → `Vec`, `Box<dyn Trait>` → `Box`, `Option<T>` → `Option`, `Self` → the impl type). Nothing is inferred through function return types, closures, iterator chains, `for` bindings, `match` or `if let` patterns, tuple or slice patterns, generics or trait resolution; those receivers keep today's fallback (every buffer `field_identifier` plus outline methods).

Once a type name is known, the buffer's Rust `TypeTable` (`highlight/rust_types.rs`: struct and union fields, enum variants, methods, consts and associated types from every `impl` and `trait` block, `type` aliases followed) supplies members in declaration order, and the catalog adds the direct children of the bare type path (`query::children` on `parent_path`, so `HashMap::insert` is found under `HashMap` whatever module it lives in), filtered to methods, variants, consts, associated types and fns, deduped by name with the buffer winning. Buffer rows are tiered above catalog rows; catalog rows keep their ranking score with the `MemberAccess` context bonus. Struct fields are not in the catalog, so a type defined outside the buffer lists only methods. At a `Foo { |` site the engine lists `Foo`'s buffer fields that are not yet written in the literal (names are scanned from the text between the literal's `{` and the caret, nested braces skipped) with insert text `name: ` unless a `:` already follows the caret; `Self { |` inside an `impl` resolves to the impl type. When the type is not defined in the buffer the site falls back to identifier completion.

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
| `query_completions` | site-classified completions (see above); sessionless calls fall back to prefix / crate / phrase catalog search |
| `import_edit` | `TextEdit` adding `use <path>;` to a Rust buffer, or none when already imported |
| `signature_help` | signature of the call enclosing the caret with parameter ranges and the active parameter |
| `find_definitions` | identifier under the caret to buffer outline or index definitions |
| `run_check` | `cargo check` diagnostics with absolute paths and byte ranges |
| `format_rust` | rustfmt a buffer |
| `run_check_c` | `clang -fsyntax-only` diagnostics for one C or C++ file, flags from `compile_commands.json` |
| `has_tool` | whether a toolchain binary (`clang-format`, …) is on PATH or in the usual install dirs |
| `format_c` | clang-format a C or C++ buffer (`--assume-filename` from the buffer path so `.clang-format` is honoured) |
| `import_edit` | the `use` line to insert for a hit's `import_path`, as a `TextEdit` the app applies after accepting the hit (caret shifted past the inserted text) |
| `signature_help` | signature of the call around the caret with parameter byte ranges and the active index; the app queries it after accepting a fn/method/macro hit, on `(` and `,` in Rust/C/C++, and on every caret move while its popup is visible |
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
