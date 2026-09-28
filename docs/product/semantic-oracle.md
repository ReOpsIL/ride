# Semantic oracle: rust-analyzer for Rust completion

Ride's own typing is heuristic (`TypeTable`, three hops, buffer and header types). It cannot type `s.split('.').`: `split` returns `Split<'a, P>` and the iterator methods come from `impl Iterator for Split`, which neither the buffer nor the catalog links. KD-20 (`plan/roadmap/level-up.md`) adopts rust-analyzer as a sidecar behind a boundary; this is the first slice of release 2.1 (cards 2.1-1, 2.1-2 and the member-list part of 2.1-4).

## Invariant

The keystroke path never waits on rust-analyzer. `query_completions` reads a cache; a miss sends a job to a background worker and returns the heuristic answer at once. When the worker stores an answer it tells the app, which re-queries if the caret has not moved.

## Sites

| Site | rust-analyzer answer | Ride's own sources |
|---|---|---|
| Member access `x.` | Replaces them: fields, then inherent methods, then trait methods, each alphabetical | Used until the answer arrives or when rust-analyzer is off |
| `Type::` path | Replaces them, in rust-analyzer's relevance order | Same fallback |
| Identifier | First, in relevance order (locals, then types, then the rest), scored above everything else | Keyword snippets and catalog items rust-analyzer cannot see (not imported, or from crates that are not dependencies) are added after it, with their import path, when no in-scope item has the same name |
| `use` path | First | Catalog crates and children not in its answer, plus `self` and `*` inside a group |

rust-analyzer returns the full list for a site whether it is asked at the start of the word or at the caret, so every site is asked at the start of the word and the typed prefix is filtered in the engine (prefix or camel/snake hump, as the app narrows). Keywords, snippets and attribute names from rust-analyzer are dropped; Ride's own keyword snippets stay. Macros are named without `!` and keep rust-analyzer's `name!($0)` snippet, matching the catalog's convention. An empty answer is not cached, so a path into a crate that is not a dependency keeps the catalog's children.

## Flow

1. `snapshot::build` calls `engine/oracle_sites.rs::lookup` for a Rust member-access, identifier, `Type::` or `use` site in a session with a path; the site decides the `Shape` (members or scope) the answer is converted with.
2. The key is `SiteKey` (session, byte where the word starts, hash of the text before it), so typing more of the word keeps hitting the same entry and an edit above it misses.
3. Hit: the site's source (`access`, `identifier`, `paths`) answers from the cached list through `engine/oracle_hits.rs`, filtered by the typed prefix and merged as in the table above. When `(` already follows the caret the call snippet drops to the bare name.
4. Miss: `Oracle::request` claims the key (no duplicate jobs) and sends a `SiteJob` with the full buffer text plus every other session whose text changed since it was last sent to rust-analyzer.
5. `oracle/worker.rs` (thread `ride-oracle`) drops a job when a newer one for the same session is queued, resolves the Cargo workspace root (`cargo locate-project --workspace`, cached per directory), starts or reuses the `Sidecar` for that root, waits for `experimental/serverStatus` quiescent (up to 180 s, abandoning if superseded), syncs documents with full-text `didOpen`/`didChange`, and asks `textDocument/completion` at the start of the word (5 s timeout, `$/cancelRequest` on timeout).
6. A non-empty answer goes into `Facts` (64 entries, oldest first out) and `OracleListener.on_completions_ready(session)` fires. The app (`CompletionSession+Oracle.swift`) re-schedules the completion when the popup is showing in that view, or, with no popup, when the caret and text length are what they were when the query was scheduled; Escape clears that pending re-query.

## Module layout

| Path | Responsibility |
|---|---|
| `src/wire/` | Content-Length JSON framing and the id-keyed response `Mailbox`, shared with the DAP transport |
| `src/oracle/lsp/` | LSP client: spawn, request with timeout, notifications, reader pump (answers server requests with `null`, tracks quiescence), position encoding (UTF-8 negotiated, UTF-16 fallback), URIs, message builders |
| `src/oracle/sidecar.rs` | One rust-analyzer per Cargo root: initialize, document sync, member completion |
| `src/oracle/items/` | LSP `CompletionItem` → `CompletionHit`: kind mapping, name from the label, call snippet from `textEdit`, trait name (`as Iterator`) in `detail`; `members.rs` and `scope.rs` order the two shapes |
| `src/oracle/worker.rs` | The job loop, readiness wait, restart accounting |
| `src/oracle/service.rs` | `Oracle`: enable/disable, cache reads, job requests, session forget, stop all |
| `src/engine/oracle_sites.rs`, `oracle_hits.rs`, `oracle_api.rs` | Snapshot lookup; prefix filtering and merging with Ride's sources; FFI `set_oracle_enabled`, `oracle_status`, `set_oracle_listener` |

## rust-analyzer setup

- Found with `toolchain::find_tool` and accepted only if `rust-analyzer --version` succeeds (the rustup proxy exists without the component). Missing: status `Unavailable`, message "rustup component add rust-analyzer".
- The child gets `toolchain::search_path()` as `PATH` so it finds `cargo` from a Finder launch.
- `initializationOptions`: `checkOnSave` off and diagnostics off (Ride runs its own checks), auto-import and postfix completions off (Ride has its own), callable snippets `fill_arguments`.
- Document URIs use the canonical path. `cargo locate-project` reports the resolved root, so a project opened through a symlink (`/var` → `/private/var`, a linked checkout) otherwise sent documents rust-analyzer considered outside the workspace, and completion came back empty.
- A sidecar whose process exits is dropped and restarted by the next job; three exits for one root in five minutes stop restarts (`Failed`).

## States

`Off` (preference off) → `Idle` (enabled, nothing started) → `Starting` (process up, workspace loading) → `Ready`; `Unavailable` (not installed) and `Failed` (exit or give-up) carry a message. Preferences → Editor → Popups shows the state under "Type-aware Rust completion (rust-analyzer)", on by default.

## Verification

- `cargo test --test oracle_live` drives the engine against a real rust-analyzer on temporary crates (skipped when not installed): `split('.').co` becomes `collect`, `copied`, `count` after the answer; `let m: Ha` lists `HashMap`; `Vec::with` lists `with_capacity`; `use std::coll` lists `collections`.
- `ride-engine complete <file> --find "split('.')." --semantic --repeat 200` prints the answer after rust-analyzer's and times cached queries (p95 about 0.1 ms release).
- Self-test step `semantic member completion` types `"a.b".split('.').` in the demo crate and waits for `collect` in the popup.
