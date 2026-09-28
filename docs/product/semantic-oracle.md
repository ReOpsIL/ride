# Semantic oracle: rust-analyzer and clangd for completion

Ride's own typing is heuristic (`TypeTable`, three hops, buffer and header types). It cannot type `s.split('.').` in Rust (`split` returns `Split<'a, P>` and the iterator methods come from `impl Iterator for Split`) or `auto it = rects.begin(); it->` in C++. KD-20 (`plan/roadmap/level-up.md`) adopts language servers as sidecars behind a boundary: rust-analyzer for Rust, clangd for C and C++. This covers cards 2.1-1, 2.1-2, 2.1-3 and the completion part of 2.1-4.

## Invariant

The keystroke path never waits on a language server. `query_completions` reads a cache; a miss sends a job to a background worker and returns Ride's own answer at once. When the worker stores an answer it tells the app, which re-queries.

## Sites

| Site | Server answer | Ride's own sources |
|---|---|---|
| Member access `x.`, `p->` | Replaces them. Rust: fields, then inherent methods, then trait methods, each alphabetical. C/C++: clangd's relevance order | Used until the answer arrives or when the servers are off |
| `Type::` / `ns::` path | Replaces them, in the server's relevance order | Same fallback |
| Identifier | First, in relevance order (locals, then types, then the rest), scored above everything else | Keyword snippets, and in Rust catalog items rust-analyzer cannot see (not imported, or from crates that are not dependencies), added after it with their import path when no in-scope item has the same name |
| `use` path (Rust) | First | Catalog crates and children not in its answer, plus `self` and `*` inside a group |
| `#include` (C/C++) | Not asked | Ride's include-path completion |

Both servers return the full list for a site when asked at the start of the word, so every site is asked there and the typed prefix is filtered in the engine (prefix or camel/snake hump, as the app narrows). Keywords and snippets from the servers are dropped; Ride's own keyword snippets stay. An empty answer is not cached, so a path into a crate that is not a dependency keeps the catalog's children.

## Dialects

`oracle/items/` converts `CompletionItem`s per server (`Dialect`):

- rust-analyzer: name from the label (`rev(alias reverse) (as Iterator)` → `rev`), trait owner in `detail`, macros named without `!` keeping the `name!($0)` snippet (the catalog's convention), attribute names (kind 18) dropped, signature `fn name(params) -> T`.
- clangd: labels start with a space and may be qualified (` geo::Registry` → name `Registry`, insert `geo::Registry`), the return type is `detail` and the parameters are in the label (signature `bool is_square() const`), macros arrive as plain text and map to `Const`, classes and class templates to `Class`, namespaces to `Namespace`, aliases (kind 18) to `Type`. Each overload is its own item; the engine keeps one row per name.

## Flow

1. `snapshot::build` calls `engine/oracle_sites.rs::lookup` for a Rust, C or C++ site in a session with a path; the site decides the `Shape` (members or scope).
2. The key is `SiteKey` (session, byte where the word starts, hash of the text before it), so typing more of the word keeps hitting the same entry and an edit above it misses.
3. Hit: the site's source (`access`, `identifier`, `paths`) answers from the cached list through `engine/oracle_hits.rs`, filtered by the typed prefix and merged as in the table above. When `(` already follows the caret the call snippet drops to the bare name.
4. Miss: `Oracle::request` claims the key (no duplicate jobs) and sends a `SiteJob` with the full buffer text, its language, and every other session whose text changed since it was last sent.
5. `oracle/worker.rs` (thread `ride-oracle`) drops a job when a newer one for the same session is queued, picks the `Server` for the language, resolves its root (cached per directory), starts or reuses the `Sidecar` for (server, root), waits until it is ready, syncs documents with full-text `didOpen`/`didChange`, and asks `textDocument/completion` at the start of the word (`$/cancelRequest` on timeout).
6. A non-empty answer goes into `Facts` (64 entries, oldest first out) and `OracleListener.on_completions_ready(session)` fires. The app (`CompletionSession+Oracle.swift`) re-schedules the completion when the popup is showing in that view, or, with no popup, when the caret and text length are what they were when the query was scheduled; Escape clears that pending re-query.

## Servers (`oracle/server.rs`)

| | rust-analyzer | clangd |
|---|---|---|
| Found | `toolchain::find_tool`, accepted only if `--version` succeeds (the rustup proxy exists without the component) | Same; Xcode's `clangd` is on the toolchain path |
| Root | `cargo locate-project --workspace` | The project whose compile database covers the file (`check::project_root`), else the file's directory |
| Ready | `experimental/serverStatus` quiescent, up to 180 s | At once; `--completion-parse=always` makes the request wait for the preamble instead of answering from text |
| Completion timeout | 5 s | 30 s (the first preamble of a file with heavy headers) |
| Options | `checkOnSave` and diagnostics off (Ride runs its own checks), auto-import and postfix off, callable snippets `fill_arguments` | `--limit-results=0` (default is 100), `--header-insertion=never`, `--function-arg-placeholders`, `--background-index=false` (it would write `.cache/clangd` into the project) |
| Missing | "rustup component add rust-analyzer" | "install Xcode or the Command Line Tools" |

Compile commands for clangd come from Ride, not from clangd's own database discovery. Before a document's `didOpen`, the sidecar sends `workspace/didChangeConfiguration` with `compilationDatabaseChanges` for that file: `clang` plus `check::invocation` (the same `-x`, flags and working directory Ride's clang check uses, from the nearest `compile_commands.json` or the default flags) plus the file. clangd resolves a relative `"directory"` against its own working directory, so the sample projects' databases (`"directory": ".."`) otherwise gave it a generic command that could not find the project headers, and every answer was a word-based fallback.

Common to both: the child gets `toolchain::search_path()` as `PATH` (so rust-analyzer finds `cargo` from a Finder launch); document URIs use the canonical path (a project opened through a symlink such as `/var` → `/private/var` otherwise looked outside rust-analyzer's workspace and completion came back empty); a sidecar whose process exits is dropped and restarted by the next job, and three exits for one (server, root) in five minutes stop restarts (`Failed`).

## Module layout

| Path | Responsibility |
|---|---|
| `src/wire/` | Content-Length JSON framing and the id-keyed response `Mailbox`, shared with the DAP transport |
| `src/oracle/lsp/` | LSP client: spawn, request with timeout, notifications, reader pump (answers server requests with `null`, tracks quiescence), position encoding (UTF-8 negotiated, UTF-16 fallback), URIs, message builders |
| `src/oracle/server.rs`, `clangd.rs`, `discover.rs` | Per-server program, arguments, options, root, readiness, timeout, dialect; clangd compile settings; finding the binary |
| `src/oracle/sidecar.rs` | One server process per (server, root): initialize, document sync, completion |
| `src/oracle/items/` | `CompletionItem` → `CompletionHit` per dialect; `members.rs` and `scope.rs` order the two shapes |
| `src/oracle/worker.rs` | The job loop, readiness wait, restart accounting |
| `src/oracle/service.rs` | `Oracle`: enable/disable, cache reads, job requests, session forget, stop all |
| `src/check/invocation.rs` | The clang command for a file, shared by Ride's clang check and clangd |
| `src/engine/oracle_sites.rs`, `oracle_hits.rs`, `oracle_api.rs` | Snapshot lookup; prefix filtering and merging with Ride's sources; FFI `set_oracle_enabled`, `oracle_status`, `set_oracle_listener` |

## States

`Off` (preference off) → `Idle` (enabled, nothing started) → `Starting` (process up, project loading) → `Ready`; `Starting` and `Ready` carry the server's name, `Unavailable` (not installed) and `Failed` (exit or give-up) carry a message. There is one status for both servers; it shows the last one that changed. Preferences → Editor → Popups shows it under "Type-aware completion (rust-analyzer, clangd)", on by default.

## Verification

- `cargo test --test oracle_live` (rust-analyzer) and `--test oracle_clangd_live` (clangd) drive the engine against the real servers on temporary projects and skip when a server is not installed. Rust: `split('.').co` becomes `collect`, `copied`, `count`; `let m: Ha` lists `HashMap`; `Vec::with` lists `with_capacity`; `use std::coll` lists `collections`. C++ with a relative-directory database: `it->is` on an `auto` iterator is `is_square` (`bool is_square() const`), `label.app` on a `std::string` lists `append`, `geo::sc` is `scale_all`.
- `ride-engine complete <file> --find "split('.')." --semantic --repeat 200` prints the answer after the server's and times cached queries (p95 about 0.1 ms release).
- Self-test steps `semantic member completion` (Rust demo, `"a.b".split('.').` → `collect`) and `semantic cpp member completion` (C++ demo, `auto it = rects.begin(); it->` → `is_square`).
