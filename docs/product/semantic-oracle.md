# Semantic oracle: rust-analyzer for member completion

Ride's own typing is heuristic (`TypeTable`, three hops, buffer and header types). It cannot type `s.split('.').`: `split` returns `Split<'a, P>` and the iterator methods come from `impl Iterator for Split`, which neither the buffer nor the catalog links. KD-20 (`plan/roadmap/level-up.md`) adopts rust-analyzer as a sidecar behind a boundary; this is the first slice of release 2.1 (cards 2.1-1, 2.1-2 and the member-list part of 2.1-4).

## Invariant

The keystroke path never waits on rust-analyzer. `query_completions` reads a cache; a miss sends a job to a background worker and returns the heuristic answer at once. When the worker stores an answer it tells the app, which re-queries if the caret has not moved.

## Flow

1. `snapshot::build` calls `engine/oracle_members.rs::lookup` for a Rust `MemberAccess` site in a session with a path.
2. The key is `MemberKey` (session, byte after the dot, hash of the text before it), so typing a prefix after the dot keeps hitting the same entry and an edit above it misses.
3. Hit: `access::hits` answers from the cached list, filtered by the typed prefix; the heuristic sources are skipped. When `(` already follows the caret the call snippet drops to the bare name.
4. Miss: `Oracle::request` claims the key (no duplicate jobs) and sends a `MemberJob` with the full buffer text plus every other session whose text changed since it was last sent to rust-analyzer.
5. `oracle/worker.rs` (thread `ride-oracle`) drops a job when a newer one for the same session is queued, resolves the Cargo workspace root (`cargo locate-project --workspace`, cached per directory), starts or reuses the `Sidecar` for that root, waits for `experimental/serverStatus` quiescent (up to 180 s, abandoning if superseded), syncs documents with full-text `didOpen`/`didChange`, and asks `textDocument/completion` at the byte after the dot (5 s timeout, `$/cancelRequest` on timeout).
6. A non-empty answer goes into `Facts` (64 entries, oldest first out) and `OracleListener.on_members_ready(session)` fires. The app (`CompletionSession+Oracle.swift`) re-schedules the completion if the same view is focused with the same caret and text length it had when the query was scheduled; Escape clears that pending re-query.

## Module layout

| Path | Responsibility |
|---|---|
| `src/wire/` | Content-Length JSON framing and the id-keyed response `Mailbox`, shared with the DAP transport |
| `src/oracle/lsp/` | LSP client: spawn, request with timeout, notifications, reader pump (answers server requests with `null`, tracks quiescence), position encoding (UTF-8 negotiated, UTF-16 fallback), URIs, message builders |
| `src/oracle/sidecar.rs` | One rust-analyzer per Cargo root: initialize, document sync, member completion |
| `src/oracle/items.rs` | LSP `CompletionItem` → `CompletionHit`: methods, functions and fields only; name from the label, call snippet from `textEdit`, trait name (`as Iterator`) in `detail`; fields, then inherent, then trait methods |
| `src/oracle/worker.rs` | The job loop, readiness wait, restart accounting |
| `src/oracle/service.rs` | `Oracle`: enable/disable, cache reads, job requests, session forget, stop all |
| `src/engine/oracle_members.rs`, `oracle_api.rs` | Snapshot lookup and completion consumer; FFI `set_oracle_enabled`, `oracle_status`, `set_oracle_listener` |

## rust-analyzer setup

- Found with `toolchain::find_tool` and accepted only if `rust-analyzer --version` succeeds (the rustup proxy exists without the component). Missing: status `Unavailable`, message "rustup component add rust-analyzer".
- The child gets `toolchain::search_path()` as `PATH` so it finds `cargo` from a Finder launch.
- `initializationOptions`: `checkOnSave` off and diagnostics off (Ride runs its own checks), auto-import and postfix completions off (Ride has its own), callable snippets `fill_arguments`.
- Document URIs use the canonical path. `cargo locate-project` reports the resolved root, so a project opened through a symlink (`/var` → `/private/var`, a linked checkout) otherwise sent documents rust-analyzer considered outside the workspace, and completion came back empty.
- A sidecar whose process exits is dropped and restarted by the next job; three exits for one root in five minutes stop restarts (`Failed`).

## States

`Off` (preference off) → `Idle` (enabled, nothing started) → `Starting` (process up, workspace loading) → `Ready`; `Unavailable` (not installed) and `Failed` (exit or give-up) carry a message. Preferences → Editor → Popups shows the state under "Type-aware Rust completion (rust-analyzer)", on by default.

## Verification

- `cargo test --test oracle_live` drives the engine against a real rust-analyzer on a temporary crate (skipped when not installed): the first query has no `collect`, the listener fires, the second query is `collect`, `copied`, `count` for prefix `co`.
- `ride-engine complete <file> --find "split('.')." --semantic --repeat 200` prints the answer after rust-analyzer's and times cached queries (p95 about 0.1 ms release).
- Self-test step `semantic member completion` types `"a.b".split('.').` in the demo crate and waits for `collect` in the popup.
