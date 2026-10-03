# Semantic oracle: rust-analyzer and clangd for completion and definitions

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

## Definitions

Go to Definition (⌘-click, F12), Quick Definition (⌘Y), Quick Documentation (⌃J, F1, the hover card) and Find Usages all start from `Engine::find_definitions`. It now answers, in order: an `#include` line (Ride's own), then the server (`engine/oracle_defs.rs`), then Ride's heuristics.

- The server step builds the document text under the engine read lock, releases it, and calls `Oracle::definitions`, which uses a sidecar that is already running and ready (1.5 s per request). With none, it asks the worker to start one (`Msg::Warm`) and returns nothing, so this lookup falls back and the next one gets the server.
- `oracle/definition.rs` decides what to ask: `textDocument/definition` always (answers are `LocationLink`s, whose name range is used, or `Location`s); clangd also `textDocument/declaration`, so a method declared in a header and defined in a `.cpp` keeps both segments in Quick Definition; rust-analyzer also `textDocument/implementation` (at most 8) when every definition lies inside the project root, so a trait method lists its `impl`s without listing every `Clone` impl in the dependencies for `x.clone()`.
- When the name under the caret is itself declared there (an outline item starts at it), the caret's own position is added: a server asked on a definition answers with the other side only (clangd on `Circle::area` in the `.cpp` returns the header declaration), and Quick Definition used to show both.
- Each target becomes a hit at the name's byte (`source_path` empty when it is the current document, so the jump stays in the buffer), with the declaration line up to `{` or `;` as the signature and a kind read from its keyword. Quick Definition and Quick Documentation lift the item and its doc comment from there as before.
- The intention light bulb recomputes on every caret move on the per-document session queue, which also applies edits; it keeps Ride's own definitions (`symbols::own_definitions`) so a server round trip never delays typing. Hover and Quick Documentation moved from that queue to the workspace lane for the same reason.

## Type Info

Code › Type Info (⌃⇧P) calls `Engine::type_info`, which asks the server's `textDocument/hover` at the caret (same ready-or-start rule and 1.5 s cap as definitions). `oracle/hover.rs` takes the first fenced code block as the signature (`let parts: Vec<&str>`) and the rest as the body (clangd: `Type: iterator (aka __wrap_iter<geo::Rect *>)`), and the app shows it in the documentation popup. Without an answer the popup says so instead of guessing.

## Flow (completion)

1. `snapshot::build` calls `engine/oracle_sites.rs::lookup` for a Rust, C or C++ site in a session with a path; the site decides the `Shape` (members or scope).
2. The key is `SiteKey` (session, byte where the word starts, hash of the text before it), so typing more of the word keeps hitting the same entry and an edit above it misses.
3. Hit: the site's source (`access`, `identifier`, `paths`) answers from the cached list through `engine/oracle_hits.rs`, filtered by the typed prefix and merged as in the table above. When `(` already follows the caret the call snippet drops to the bare name.
4. Miss: `Oracle::request` claims the key (no duplicate jobs) and sends a `SiteJob` with the full buffer text, its language, and every other session whose text changed since it was last sent.
5. `oracle/worker.rs` (thread `ride-oracle`) drops a job when a newer one for the same session is queued, picks the `Server` for the language, resolves its root (cached per directory), starts or reuses the `Sidecar` for (server, root) in the shared `Fleet`, waits until it is ready, syncs documents with full-text `didOpen`/`didChange`, and asks `textDocument/completion` at the start of the word (`$/cancelRequest` on timeout).
6. A non-empty answer goes into `Facts` (64 entries, oldest first out) and `OracleListener.on_completions_ready(session)` fires. The app (`CompletionSession+Oracle.swift`) re-schedules the completion when the popup is showing in that view, or, with no popup, when the caret and text length are what they were when the query was scheduled; Escape clears that pending re-query.

## Servers (`oracle/server.rs`)

| | rust-analyzer | clangd |
|---|---|---|
| Found | `toolchain::find_tool`, accepted only if `--version` succeeds (the rustup proxy exists without the component) | Same; Xcode's `clangd` is on the toolchain path |
| Root | `cargo locate-project --workspace` | The project whose compile database covers the file (`check::project_root`), else the file's directory |
| Ready | `experimental/serverStatus` quiescent, up to 180 s | At once; `--completion-parse=always` makes the request wait for the preamble instead of answering from text |
| Completion timeout | 5 s | 30 s (the first preamble of a file with heavy headers) |
| Options | `checkOnSave` and diagnostics off (Ride runs its own checks), auto-import and postfix off, callable snippets `fill_arguments` | `--limit-results=0` (default is 100), `--header-insertion=never`, `--function-arg-placeholders`, `--compile-commands-dir` pointing at Ride's copy of the database |
| Missing | "rustup component add rust-analyzer" | "install Xcode or the Command Line Tools" |

Compile commands for clangd come from Ride, not from clangd's own database discovery:

- At launch Ride writes the project's database, normalized to absolute `directory` and `file` (`check::normalized`), to `<index dir>/oracle/clangd/<root hash>/compile_commands.json` and passes that folder as `--compile-commands-dir`. clangd resolves a relative `"directory"` against its own working directory, so the sample databases (`"directory": ".."`) otherwise gave it a generic command that could not find the project headers, and every answer was a word-based fallback. The fixed folder also stops clangd from finding the project's own database, and its background index is stored next to the database it read, so `.cache/clangd` lands in Ride's folder, never in the project. With the index, definitions in other translation units (an out-of-line `Rect::perimeter` in `shapes.cpp`) resolve.
- A file in a project without any database gets `workspace/didChangeConfiguration` with `compilationDatabaseChanges`: `clang` plus `check::invocation` (the default flags Ride's clang check uses) plus the file. Files under a database never get it: an override makes clangd stop consulting the background index for that file, and cross-file definitions came back as the header declaration only.

The Tools panel (`discover/tools.rs`) lists both servers with their install commands (`rustup component add rust-analyzer`, `xcode-select --install`). `rust-analyzer`, `rustfmt` and `cargo-clippy` are rustup proxies that exist in `~/.cargo/bin` even when the component is missing, so those rows count as installed only when `--version` runs (`toolchain::find_runnable`, also used to find the servers).

Common to both: the child gets `toolchain::search_path()` as `PATH` (so rust-analyzer finds `cargo` from a Finder launch); document URIs use the canonical path (a project opened through a symlink such as `/var` → `/private/var` otherwise looked outside rust-analyzer's workspace and completion came back empty); a sidecar whose process exits is dropped and restarted by the next job, and three exits for one (server, root) in five minutes stop restarts (`Failed`).

## Module layout

| Path | Responsibility |
|---|---|
| `src/wire/` | Content-Length JSON framing and the id-keyed response `Mailbox`, shared with the DAP transport |
| `src/oracle/lsp/` | LSP client: spawn, request with timeout, notifications, reader pump (answers server requests with `null`, tracks quiescence), position encoding (UTF-8 negotiated, UTF-16 fallback), URIs, message builders |
| `src/oracle/server.rs`, `clangd.rs`, `discover.rs` | Per-server program, arguments, options, root, readiness, timeout, dialect; clangd compile settings; finding the binary |
| `src/oracle/fleet.rs`, `launch.rs` | The shared map of running sidecars keyed by (server, root); starting, exit accounting and status |
| `src/oracle/sidecar.rs` | One server process per (server, root), usable from several threads: initialize, document sync (locked), completion, definition and declaration |
| `src/oracle/target.rs`, `lsp/locations.rs` | Definition answers → path and byte of the name |
| `src/oracle/items/` | `CompletionItem` → `CompletionHit` per dialect; `members.rs` and `scope.rs` order the two shapes |
| `src/oracle/worker.rs` | The job loop, readiness wait, restart accounting |
| `src/oracle/service.rs` | `Oracle`: enable/disable, cache reads, job requests, session forget, stop all |
| `src/check/invocation.rs` | The clang command for a file, shared by Ride's clang check and clangd |
| `src/engine/oracle_sites.rs`, `oracle_hits.rs`, `oracle_defs.rs`, `oracle_api.rs` | Completion lookup; prefix filtering and merging with Ride's sources; definitions from the server; FFI `set_oracle_enabled`, `oracle_status`, `set_oracle_listener` |

## States

`Off` (preference off) → `Idle` (enabled, nothing started) → `Starting` (process up, project loading) → `Ready`; `Starting` and `Ready` carry the server's name, `Unavailable` (not installed) and `Failed` (exit or give-up) carry a message. There is one status for both servers; it shows the last one that changed. Preferences → Editor → Popups shows it under "Type-aware completion (rust-analyzer, clangd)", on by default.

## Verification

- `cargo test --test oracle_live` (rust-analyzer) and `--test oracle_clangd_live` (clangd) drive the engine against the real servers on temporary projects and skip when a server is not installed. Rust: `split('.').co` becomes `collect`, `copied`, `count`; `let m: Ha` lists `HashMap`; `Vec::with` lists `with_capacity`; `use std::coll` lists `collections`. C++ with a relative-directory database: `it->is` on an `auto` iterator is `is_square` (`bool is_square() const`), `label.app` on a `std::string` lists `append`, `geo::sc` is `scale_all`.
- Definitions: `collect` in `"a.b".split('.').collect()` resolves into core's `iterator.rs` and Quick Documentation shows its doc; `it->is_square()` resolves into `shapes.hpp` (`bool is_square() const`); `r.perimeter()` lists both `shapes.hpp` and, once indexed, `shapes.cpp`, with no `.cache` in the project.
- `ride-engine complete <file> --find "split('.')." --semantic --repeat 200` prints the answer after the server's and times cached queries (p95 about 0.1 ms release).
- Self-test steps `semantic member completion` (Rust demo, `"a.b".split('.').` → `collect`) and `semantic cpp member completion` (C++ demo, `auto it = rects.begin(); it->` → `is_square`).
