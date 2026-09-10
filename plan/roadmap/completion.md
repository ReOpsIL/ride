# Completion plan (2026-09-10)

Goal: the best completion we can build without a model. Every completion site answers in under 2 ms in the engine and paints on the next frame; every row says what the item is, where it comes from and how to call it; accepting a row does the right thing (parens, snippets, imports). Sequencing follows the two reported gaps first (`use` never lists crates, `#include` never lists headers), then the pipeline and ranking work those gaps expose.

## Status (2026-09-10)

| Phase | Item | State |
|---|---|---|
| 1 | Engine-side `CompletionSite` classifier (Rust, C, C++, plain) with caret-marker tests | done (`highlight/site/`, `tests/sites.rs`) |
| 1 | `use` crates and children via `parent_path`; `crate`/`self`/`super` mapping; brace groups | done (`engine/paths.rs`) |
| 1 | `::` children, associated items first | done |
| 1 | `#include` completion, compile-db dirs plus cached `clang -E -v` system dirs | done (`includes/`, `discover/system_includes.rs`) |
| 1 | App triggers, empty prefix, ⌃Space, replace range from the engine, local narrowing | done (`app/Ride/Completion/CompletionTrigger.swift`, `CompletionNarrowing.swift`) |
| 1 | Schema v11 (`parent_path`, `name_hump`, `reachable`, `deprecated`, variants, cfg(test) drop, derive names) | done |
| 2 | Merged buffer + header + keyword + catalog pipeline, one scorer, mention/keyword yield | done (`engine/identifier.rs`, `engine/merge.rs`, `src/score.rs`) |
| 2 | Import set and prelude tiers, unreachable filter, exact-match cap, typed case | done |
| 2 | Hump matching | done (`name_hump` clause); `nucleo-matcher` typo tolerance not needed yet |
| 2 | Scenario tests and `ride-engine complete` CLI | done (`tests/completion_sites.rs`, `tests/edits_and_signatures.rs`) |
| 3 | Outline signature/doc, local types as detail | done (`highlight/c_docs.rs`, `c_locals.rs`, `rust_locals.rs`) |
| 3 | Row extras, doc card, signature help popup | done (`SignatureHelpController.swift`, `CompletionDocCard.swift`) |
| 4 | Call and keyword snippets, postfix templates | done (`engine/snippets.rs`, `engine/postfix.rs`) |
| 4 | Auto-import (`import_edit`) | done |
| 4 | Rust receiver typing, struct-literal fields | done (`highlight/rust_receiver.rs`, `rust_types.rs`, `engine/rust_members.rs`) |
| 4 | Enum variants, `#[derive]` and attribute completion, C directives | done |
| 5 | Scope cache, system header summaries on disk, C++ `::`, field chains, `auto` | done (`highlight/scope.rs`, `engine/reach.rs`, `engine/header_store.rs`, `highlight/c_scopes.rs`, `c_members.rs`) |

## Audit

| # | Finding | Where |
|---|---|---|
| 1 | An empty prefix never queries. The tokenizer returns nil when nothing is typed after the trigger, so `std::`, `foo.`, `p->`, `use `, `#include <` show nothing until a letter is typed. | `app/Ride/Completion/CompletionTokenizer.swift` (`if prefix.isEmpty { return nil }`) |
| 2 | Site classification lives in Swift and is Rust-shaped. `#include "` is treated as a string and vetoed; `<` is not a path char; `CompletionPosition` uses Rust keywords for every language; `::` sets crate/module only for the catalog. | `CompletionTokenizer.swift`, `CompletionPosition.swift` |
| 3 | `use` never lists crates. `QueryMode.prefixCrates` exists in the engine (`tests/query.rs::crate_prefix_mode`) and the crate set with scopes is already discovered (`src/discover`, `Scope::{Workspace,DirectDep,Sysroot,Transitive}`), but the app never sends that mode. | `CompletionTokenizer.swift`, `src/query/items.rs` |
| 4 | Buffer locals vanish at three characters. The tokenizer switches to `.items`, `engine/query.rs` computes local hits only in `BufferLocal`, and `query::run_query` ignores `buffer_hits` for `Items`. `let counter` is offered for `co` and gone for `cou`. | `src/engine/query.rs`, `src/query/mod.rs` |
| 5 | `::` paths have no children query. `current_module` becomes a regex on `path_exact`; there is no "direct children of this path" lookup and no `Type::assoc` completion. | `src/query/items.rs` |
| 6 | Rust `.` has no receiver typing (`no_receiver`, `empty_table`), so the fallback lists every `field_identifier` in the buffer. | `src/highlight/grammar/rust.rs`, `src/highlight/members.rs` |
| 7 | Ranking knows nothing about scope. No boost for names imported by `use` lines or defined in the buffer, no prelude tier. An exact match in a transitive crate outranks std (`Has` → `wasi::Fields::has` above `core::hash::Hash`). Unreachable paths surface (`std::sys::pal::windows::c::windows_sys::TOKEN_*`) and so do `#[cfg(test)]` fns (`tests::serde_version` for `ser`). | `src/query/rank.rs`, `src/index/doc.rs`, `src/extract/vis.rs` |
| 8 | Strict prefix only. No camel-hump (`HM` → `HashMap`), no subsequence, no typo tolerance. | `src/query/items.rs`, `src/query/hit.rs` |
| 9 | Local and header rows are blank. `CompletionHit::local` leaves signature and doc empty; `OutlineItem` carries name, kind and range only, so the detail column and doc card show nothing for the user's own code. | `src/ffi/query.rs`, `src/ffi/session.rs` |
| 10 | Accept inserts the bare name. No parens, no snippets, no auto-import (`todo/app/remaining.md`), no signature help after `(`. | `CompletionPopup.swift::accept` |
| 11 | Per-keystroke work that should be cached: `session.scope()` re-walks the whole tree for the include list and `TypeTable`; the include graph is re-resolved on every query. | `src/highlight/session.rs`, `src/engine/include_graph.rs` |
| 12 | System headers are unreachable: no `clang -E -v` probe, include walk capped at 64 files, no disk cache for header summaries. | `src/check/include_dirs.rs`, `src/engine/headers.rs` |

Latency today (release CLI, 807 registry crates plus sysroot): p50 0.5–1.1 ms, p95 under 1.3 ms for catalog prefixes. Budget to hold through this plan: engine p50 ≤ 2 ms, p95 ≤ 5 ms per keystroke; popup paints on the next frame.

On this machine `clang -E -x c++ - -v` reports five include directories and two framework directories; the libc++ directory holds 165 extension-less headers and the SDK `usr/include` 356 entries. Directory listings are cheap to cache by mtime.

## Design moves

**A. Site classification moves into the engine.** A `CompletionSite` per grammar (`src/highlight/site.rs`, one file per language under `site/`) reads the tree-sitter node at the caret and falls back to a short text scan when the caret sits in an `ERROR` node (a half-typed `use std::` always does). Variants: `Identifier`, `MemberAccess { receiver }`, `ScopedPath { segments }`, `UsePath { segments, in_braces }`, `Include { quoted, typed }`, `Attribute`, `Directive`, `StructLiteral { type_name }`, `None`. The app sends the caret and a `manual` flag; the response carries `replace_start_byte`, `replace_end_byte` and the site so the app can label the popup ("headers in include/"). Swift keeps only a gate: fire on an identifier character, a trigger character or ⌃Space.

**B. One candidate pipeline.** Sources (buffer locals and outline, reachable headers, imports and prelude, catalog) produce candidates; one scorer ranks them; one dedupe and truncate. The `BufferLocal` / `Items` split disappears from the app (the FFI enum stays for the CLI). The scorer gains an origin tier: enclosing scope > buffer > imported or prelude > workspace > direct dependency > sysroot > transitive, plus typed-case agreement and hump match.

**C. Rich items everywhere.** `OutlineItem` gains `signature` (declaration text up to the body) and `doc` (the preceding comment block). Buffer and header hits carry them. `CompletionHit` gains `insert_text` in snippet syntax (`name(${1:a}, ${2:b})$0`), `import_path`, `deprecated` and `detail` (the declared type of a local).

**D. Caches with clear invalidation.** A per-session `ScopeCache` (imports, includes, type table, reachable header list) rebuilt lazily on generation change. Builtin include directories per compile database and language, probed once. Directory listings for include completion keyed by mtime. Header summaries persisted under the index directory keyed by path and mtime.

**E. One schema bump.** Every new index field (`parent_path`, `reachable`, `name_hump`, `Variant` kind, `deprecated`, `import_path`) lands in a single `SCHEMA_VERSION` bump at the start of Phase 1, so the 50 s full reindex happens once.

## Phase 1 — Sites and triggers

1. `CompletionSite` classifier for Rust and C/C++ with caret-marker fixtures (`tests/completion_sites.rs`: snippet with `|`, expected site and replace range).
2. `use` completion. No segments: crates from the discovered set (workspace members, direct dependencies, `std`, `core`, `alloc`) plus `crate`, `self`, `super`, ranked workspace > direct > sysroot, each row showing version and crate doc. One or more segments: direct children of the path through a `parent_path` STRING field and a term query (no regex), plus `self` and `*` inside braces. Brace groups: the qualifier is the path before `{`. Crates and modules insert their name; typing `::` re-triggers.
3. `::` outside `use`: the same children query for modules; for a type, its associated fns, consts and types (already emitted under `Type::name`), ranked by context.
4. `#include` completion. Quoted: the including file's directory, `-iquote`, `-I`. Angled: `-I`, `-isystem`, then the builtin directories from `clang -E -x <lang> - -v` (probed once per compile database or default flag set, cached; `src/discover/system_includes.rs`). Support partial directories (`sys/`), extension-less libc++ names, directory rows ending in `/` that re-trigger, closing `>` or `"` on accept when missing. Rank project headers, then libc and libc++, then frameworks; hide `__*` internals and non-header files. Fixture include tree in `tests/`.
5. App triggers: Rust `.`, `::`, space after `use`, `#`; C/C++ `.`, `->`, `::`, `<`, `"`, `/` inside an include, `#`. Empty prefix allowed after a trigger; ⌃Space forces a query anywhere. The string-or-comment veto yields to an `Include` site. The replace range comes from the engine.

## Phase 2 — One pipeline, honest ranking

1. Merge buffer, header and catalog candidates in every query (closes audit 4). Local hits get scores from the shared scorer, not constants.
2. Scope awareness: the session parses `use` and `extern crate` lines into an import set; imported and buffer-defined names take the top tier, prelude names (`Vec`, `String`, `Option`, `Result`, `Box`, `Some`, `None`, `Ok`, `Err`, iterator traits) the next. Items whose module chain is not public are marked unreachable at extraction (`reachable` fast field) and excluded by default; `#[cfg(test)]` items are excluded outside their own file.
3. Exact-match fix: cap the exact bonus by scope so std beats a transitive crate; break ties by typed case (`Has` prefers `Hash` over `has`).
4. Hump matching: a `name_hump` field with edge-ngrams of the hump string (`HashMap` → `hm`, `read_line` → `rl`), queried alongside `name_prefix` for prefixes of two or more characters. Subsequence and typo tolerance through `nucleo-matcher` over the visible-scope name set (buffer, imports, prelude, direct-dependency public names; under 100k strings) only if hump matching leaves gaps.
5. Golden scenarios: `tests/completion_scenarios.rs` with expected top-3 per site per language against the fixture index; extend `query_is_fast_on_fixture` per site. CLI `ride-engine complete <file> --byte N` for probing without the app.

## Phase 3 — Informative rows

1. `OutlineItem.signature` and `doc` for Rust, C and C++ (declaration text; preceding `///`, `/** */` or `//` block, Doxygen included). Buffer and header hits fill signature and doc, so the detail column and the doc card work for the user's own code.
2. Local variable types as detail: `let x: T`, parameters, C declarations show `x: T`; the declaring line stays the jump target.
3. Row extras: deprecated strike-through (`#[deprecated]` captured at extraction), an "import" tag when the path is not in scope, return type after fn signatures, a "+N more" footer when truncated.
4. Doc card: markdown-lite rendering through the existing `render_markdown` (code spans, lists), the ⌘-click hint, `⌘I` to expand the full doc.
5. Signature help: after accepting a fn or typing `(` or `,` inside a call, a small popup shows the signature with the active parameter highlighted, sourced from the same signature the row used; closes on `)`. New `SignatureHelpPopup` next to the completion popup.

## Phase 4 — Smarter accept

1. Snippet insert: fn and method rows insert `name(${1:a}, ${2:b})$0` built from the signature (`name()` when there are no parameters); macros insert `name!($0)`; keyword rows expand to templates (`fn`, `match`, `impl`, `for`, `if let`, `struct`; C `for`, `switch`, an include guard). App side: tab-stop navigation with Tab and Shift-Tab, placeholder selection, Esc leaves the snippet.
2. Auto-import for Rust catalog items not in scope: hits carry `import_path`, the shortest public path from re-export resolution; accept inserts the `use` line into the existing block in sorted position. Preference to turn it off.
3. Rust receiver typing, mirroring the C `TypeTable`: `self.` resolves to the enclosing impl type (fields and methods from the buffer and the catalog); `let x: T`, `fn f(x: &T)`, `let x = T::new(..)` and `T { .. }` resolve to `T`; methods come from buffer impls and catalog `T::*` (trait impls are already emitted under the type path); field chains follow declared field types. The existing fallback remains for everything else.
4. Enum variants as a `Variant` kind (`Option::Some`), struct-literal field completion at `Foo { |`, match-arm completion at `Foo::|`.
5. Attribute completion: `#[derive(|)]` from std derives plus derive macros in the catalog; `#[|]` from a fixed list of common attributes. C preprocessor directives after `#`.
6. Postfix completions (`.if`, `.match`, `.let`, `.not`, `.ref`, `.dbg`, `.unwrap`, `.return`): syntactic rewrites of the receiver expression, an opt-in list.

## Phase 5 — C/C++ depth

1. Session `ScopeCache` (audit 11) and a disk cache for header summaries so `<vector>` does not cost two hundred parses per project open; raise the file cap for system directories; hide reserved `__x` and `_X` names unless typed.
2. `::` for C++: namespace members and class statics from the buffer and reachable headers (outline items gain a scope path); `std::` served from the summarized libc++ headers filtered to non-reserved names.
3. Field chains and call results: `TypeTable` members carry their declared type string, outline fns carry a return type, `a.b->c.` resolves through them, `auto` resolves only from a constructor or cast initializer. Everything else keeps the field-name fallback.

## Effort and order

| Phase | Scope | Days |
|---|---|---|
| 1 | sites, `use`, `::`, `#include`, triggers, schema bump | 4–6 |
| 2 | merged pipeline, scope-aware ranking, hump matching, scenario tests | 4–5 |
| 3 | signatures and docs on local items, row extras, signature help | 3–4 |
| 4 | snippets, auto-import, Rust receiver typing, variants, attributes, postfix | 6–8 |
| 5 | C/C++ caches, `::`, chains | 4–5 |

Phase 1 answers the reported gaps. Phase 2 comes before 3 and 4 because every later source scores through the merged pipeline. Phases 3 to 5 are independent of each other and can be reordered by what hurts most in daily use.

## Tradeoffs

- Engine-side site classification over a smarter Swift tokenizer: the engine owns the tree, the languages already diverge, and cargo tests cover it without driving the UI.
- One schema bump over several: a bump forces a full 50 s reindex, so all new fields ship together.
- `parent_path` term queries over regex on `path_exact`: exact, fast, and they give the "children only" semantics `use` needs.
- Hump field in tantivy before `nucleo-matcher`: no new dependency, sub-millisecond, and it covers the abbreviation habit that fuzzy matching is usually wanted for.
- Heuristic Rust typing over real inference: covers `self.`, annotated locals, constructors and field chains, which is where most `.` completions happen in practice; the row labels the source so the user knows when the list is a fallback.

## Limits

- No type inference through generics, closures, iterator chains or trait resolution in Rust.
- No proc-macro expansion; derive-generated items are not visible.
- C++ templates show the members of the class body; no instantiation. `auto` resolves only from an obvious initializer.
- No cloud or local model anywhere in the path.

## Invariants to test

- Every site kind has a scenario per language asserting the top-3 and the replace range.
- Engine p50 ≤ 2 ms and p95 ≤ 5 ms on the fixture index for every site.
- A response for a stale query id is never shown (exists).
- A name defined or imported in the buffer always outranks a catalog name of equal prefix quality.
- Accepting a directory row in an include re-triggers; accepting a header row closes the delimiter.
