# Ride — Improve and Extend Plan

| Field | Value |
|---|---|
| Date | 2026-09-09 |
| Status | In progress (updated 2026-09-09) |
| Baseline | `plan/ride_draft.md` PR plan; E0–E6, A0–A2c, A4–A7, A9 done |

## State observed on 2026-09-09

Ran `./scripts/run.sh` on this repo and on a throwaway Cargo project.

Works: open folder, project tree, quick open (`Cmd+P`), tree-sitter highlighting, outline panel, cursor position in status bar, completion popup (BufferLocal + catalog), status bar index progress. Engine: 37 tests pass, clippy `-D warnings` clean after the fix below.

Found:

| # | Finding | Evidence | Root cause |
|---|---|---|---|
| 1 | Engine did not compile | `src/engine/mod.rs:61` stray `self.` | Unfinished edit left in tree. Removed. |
| 2 | Repo has zero commits | `git log` on `master`: no commits | Everything is untracked. |
| 3 | Index dir is 3.4 GB | `~/Library/Application Support/Ride/index/gen-1..gen-10`, ~350 MB each | `index/writer.rs` deletes `staging-*` only; old `gen-N` never pruned. |
| 4 | Full reindex on every open | `RideEngineClient.openWorkspace` always calls `IndexerProcess.run` | No freshness check; content hashes exist but a new generation is always written. |
| 5 | Status bar shows a raw per-crate error forever | `status.jsonl`: 8,412 of 8,510 lines repeat the `portable-simd ... missing [package]` message | `writer.rs:82` stores the last crate error in `status.message`, never cleared until finish. |
| 6 | Sysroot scan probes non-crates | `portable-simd`, `compiler-builtins` fail every run | `sysroot.rs` scans every dir under `library/`; KD-4 says `std`/`core`/`alloc` (+ their deps). |
| 7 | Completion popup floats over other apps | Popup stayed visible after switching to another app | `CompletionPopup.swift`: `hidesOnDeactivate = false`, `level = .popUpMenu`, no resign-active observer. |
| 8 | Weak ranking / single hit | `coun` → only `IntoChars::count (alloc 0.0.0)`; `Has` → only `Hash::hash` | Regex prefix over `name_exact` returns one hit; `Iterator::count`, `HashMap` not surfaced. Needs ranking tests. Sysroot version shows as `0.0.0`. |
| 9 | Dotfiles in tree | `.DS_Store`, `.idea`, `.oneshot` listed | `Workspace.swift` skips only `target` and `.git`. |
| 10 | No app tests, no app CI | `project.pbxproj` has no test target; `engine.yml` never runs `xcodebuild` | Spec A6/A7 XCTests were never added. |
| 11 | `docs/README.md` index missing | AGENTS.md references it | Never created. |

## Progress

| Phase | State |
|---|---|
| 1 Stabilize | Done: GC, fingerprint skip, warnings log, sysroot allow-list, popup lifecycle, hidden files, status label, RideTests + app CI, README/docs |
| 2 Completion quality | Done: schema v7 (edge-ngram prefix, fast-field ranks, best-per-name collector, path penalty, no stored source_chunk), context bias, re-export resolution (chains, sysroot cross-crate, extern crate aliases), richer rows, golden tests |
| 3 Backlog | Done: symbol picker (Cmd+Shift+R), project find (Cmd+Shift+F). Open: A3 split (EditorJump singleton must be reworked first) |
| 4 Extend | Done: go to definition, hover docs, cargo check panel + underlines, rustfmt on save, Cargo.lock watch, git badges, light theme. Open: auto-`use` on accept |
| 5 Distribution | `scripts/release.sh` (archive, sign, zip, optional notarize). Open: update check, universal build |

Measured on 2026-09-09 (806 crates, 1.58M docs): full reindex ~50–60 s release; query p95 < 1 ms for 3+ chars, ~13 ms for a single character.

## Phase 1 — Stabilize (first)

Order matters: commit first, then storage, then UX noise.

1. **Initial commit.** Commit the tree as-is (after this plan). Branch `main`, not `master`, to match tooling.
2. **Generation GC** (`src/index/writer.rs`, `src/index/status.rs`). After bumping `manifest.json`, delete every `gen-*` except live and previous. On engine start, run the same sweep. Acceptance: index dir ≤ 2 generations after any run.
3. **Skip redundant reindex** (`src/index/hash.rs`, `IndexerProcess.swift`). One-shot computes the crate-set fingerprint (paths + content hashes + schema version); if it matches the live manifest, exit `ready` without writing. Only the `Reindex` menu forces. Acceptance: second launch on the same project writes no generation and reports ready in < 1 s.
4. **Status message model** (`src/index/status.rs`, `StatusBarView.swift`). Replace `message: Option<String>` with `phase` + `warnings: u32`; keep per-crate errors in a `warnings.jsonl`. Status bar shows `Indexing 324/816 · 2 skipped`; click reveals the warning log. Acceptance: `status.jsonl` contains no repeated crate errors.
5. **Sysroot corpus set** (`src/discover/sysroot.rs`). Index `std`, `core`, `alloc` and the workspace members they list; skip workspace-only manifests. Give sysroot crates a real version (`rustc --version`). Fixes findings 6 and the `0.0.0` display.
6. **Popup lifecycle** (`CompletionPopup.swift`). Hide on `NSApplication.didResignActiveNotification`, on window resign key, and on tab switch. Set `hidesOnDeactivate = true`.
7. **Tree filter** (`Workspace.swift`). Hide dotfiles by default; add a `showHidden` preference.
8. **App test target + CI.** Add `RideTests` with the two XCTests the spec already names (UTF-16 round-trip, stale `query_id` drop). Add an `xcodebuild build test` job to `engine.yml` using the stub xcframework.
9. **`docs/README.md`** index and a root `README.md` with the run/build commands.

## Phase 2 — Completion quality

The popup works mechanically; ranking is the weakest visible piece.

1. **Golden ranking tests** (`tests/query.rs`). For prefixes `Has`, `Vec`, `Str`, `coun`, `len`, `Option` assert the expected top-3 on the fixture index. Write the tests before touching ranking.
2. **Context-aware boosts** (`src/query/items.rs`, `CompletionContext.swift`). Type position after `:` or `<` boosts `struct`/`enum`/`trait`; value position boosts `fn`/`method`; items named in the buffer's `use` lines get the top boost. Sysroot and direct deps outrank transitive per the spec.
3. **Wider fetch, dedupe by path.** Fetch `limit × 4` is fine, but one-hit results mean the regex clause is too narrow; add a `name` prefix term query alongside the regex and dedupe identical `path` across generations.
4. **Popup rows.** Show kind icon, crate, and the first doc line; hide version for sysroot.

## Phase 3 — Finish the 1.0 backlog

From the spec's open PRs, in this order:

1. **A8 symbol picker** (`Cmd+Shift+R`). Same hit rows, rustdoc `fn:`/`struct:` syntax, copy full path.
2. **A4b project find** (`Cmd+Shift+F`). Swift walker that skips `target/` and `.git`, results list, jump to line.
3. **A3 one split.**

## Phase 4 — Extend beyond 1.0

Highest value per effort, given the index already stores `source_path` and line:

1. **Go to definition** for workspace and catalog items (`Cmd+click`, `F12`): resolve the identifier under the caret through the index; open the source read-only for catalog hits. No rust-analyzer needed for the 80% case.
2. **Hover docs** from `doc_first_paragraph` and `signature`.
3. **`cargo check` diagnostics panel.** Run `cargo check --message-format=json` in a child on save (debounced), map spans to underlines and a bottom list. Reuse the child-process pattern from the indexer.
4. **rustfmt on save** via `rustfmt --emit stdout`, applied as a single edit to keep sessions in sync.
5. **Auto-`use` on accept** for catalog hits (spec A11 decision).
6. **E7 notify watch** so `cargo add` in a terminal updates the catalog without Reindex.
7. **Git dirty badges** in the tree via `git status --porcelain` on FSEvents.
8. **Light theme** from a second JSON in `Themes/`.

Defer until Phase 2 measurements exist: E9 embeddings, E10 rustdoc JSON, LSP.

## Phase 5 — Distribution

1. Release script: `build-engine.sh` Release + `xcodebuild archive`, codesign, notarize.
2. Sparkle or manual update check.
3. Universal build (`x86_64-apple-darwin` xcframework slice) once Apple Silicon is stable.

## Engine hygiene (ongoing)

- Latency gate in CI: `ride-engine query` p95 on the fixture index < 20 ms.
- Index size: 1.1M docs at ~350 MB per generation; audit stored fields, keep `doc_first_paragraph` only, review the Tantivy merge policy.
- Replace the 250 ms manifest poll in `src/engine/watch.rs` with an FSEvents-driven reload once E7 lands.
