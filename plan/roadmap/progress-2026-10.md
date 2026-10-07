# Ride — Progress plan (2026-10-07): ship what exists, then finish the half-built bets

Status: **draft for review, nothing started.** Supersedes the sequencing in `level-up.md` section 3 and section 6 KD-24; the card designs in `level-up.md`, `oracle-finish.md`, `plan/ai/assistant.md`, `release-1.0.md`, `close-out-1.3.md` and `next-1.3.md` stay valid where referenced.

## 1. Where things stand

| Plan | Planned | State on `main` `4ccf32b` |
|---|---|---|
| `close-out-1.3.md` | Introduce Constant, Inline, Safe Delete, intentions, hierarchy, code vision, data-safety DS-1..3 | **Done** |
| `release-1.0.md` (P-1..P-8) | Release train, onboarding, crash reports, `ride` command, C/C++ live verification, editor leftovers, site, hygiene gates | **Code-complete 2026-09-20, never tagged.** No `v*` tag locally or on `origin`; version 1.0.0 in `Cargo.toml` and pbxproj; `CHANGELOG.md` already carries a large "Unreleased" section on top of 1.0.0 |
| `level-up.md` 2.0 Git | 2.0-0 diff engine, 2.0-1 changes and commit, 2.0-2 history/blame/branches/stash, 2.0-3 conflicts, 2.0-4 local history | **Partial.** Changes panel, highlighted diff (from `git diff`), stage/unstage file, discard, commit/amend, push, pull ff-only, branch switch/create, tree badges. No `src/diff/`, no gutter markers, no hunk staging, no history, blame, stash, merge, conflicts, local history |
| `level-up.md` 2.1 oracle / `oracle-finish.md` | O-1..O-6, then type-dependent refactorings | **O-1, O-2, O-3 done** (completion, definitions, Type Info, hover from rust-analyzer and clangd). O-4 inlay hints, O-5 semantic highlighting, O-6 live type errors, Extract Function, Change Signature, base-class/trait generators: not started |
| `level-up.md` 2.2 / `plan/ai/assistant.md` | Context packs, inline edit, fix/explain from diagnostic, tests/docs generation, local model, commit messages, tools | **AI-1..AI-5 done** (engine context packs, streaming chat with threads, Explain, Add Selection, ghost text). Not started: Apply with diff preview, ⌘K inline edit, Fix with AI, generate tests/docs, local model provider, commit messages, assistant tools, persisted threads |
| `level-up.md` 2.3 debugging | Debug a test, attach UI, watchpoints, memory, assembly, core files, run ergonomics, breakpoints panel, coverage, Instruments | **Not started** (attach exists in the protocol only) |
| `level-up.md` section 4 boundaries | Edit plan, diff engine, oracle, context packs | Oracle and context packs exist. **Edit plan and diff engine do not**; rename's safe-apply is still the only shared apply path |
| Hygiene | ≤ 200–220 lines per file, CI gates | Clean: only the two generated cheat-sheet tables exceed 200 lines; latency and line-count gates in CI |

Older plans (`ride_draft.md`, `autocomplete.md`, `improve-extend.md`, `must_have.md`, `next.md`, `next-impl.md`, `completion.md`, `cheatsheet.md`, `ui-design.md`) are fully absorbed: their remaining items live in `todo/app/remaining.md` and `todo/engine/remaining.md` and are triaged below. Treat them as history.

Environment facts that shape priorities: the Anthropic account has no credits (AI is verified through OpenRouter), so a local-model provider has more value than `level-up.md` gave it; parallel self-tests on one machine interfere, which caps executor parallelism at one app card at a time.

## 2. Priorities

Ordered by leverage. Each tier should finish before the next starts, except where marked parallel (engine-only cards can run beside one app card).

### P0 — Ship (1 week)

Nothing has reached a user. Every later tier is guesswork until someone other than us runs it.

| # | Item | Notes | Days |
|---|---|---|---|
| S-1 | Release secrets and a dry run | Signing certificate, notarization key, Sparkle EdDSA key into repo secrets (`release-1.0.md` P-1 lists the names); `release.sh --dry-run` and one tag on a throwaway fork or pre-release tag to prove `release.yml` end to end | 1 |
| S-2 | Verify the unreleased features | Full gates on `main`: engine tests, RideTests, self-tests alone (Rust, C++, C, AI chat, Git coverage). Close the open Git item "run RideTests and the self-test on the Git app layer". Replace Git menu-coverage exemptions with a scratch-repo self-test for commit, branch and push (`todo/app` Git follow-ups) | 2 |
| S-3 | Tag and publish | Decision D-1 below. Tag, let CI publish zip, dSYM, appcast; bump the cask; check Sparkle sees the update from the previous build | 1 |
| S-4 | Push/pull timeout | A blocking credential helper hangs the Changes panel forever; bound it and surface the error. Small, user-visible, ships with the release | 0.5 |

Exit: a stranger installs from the cask, and an installed copy receives the next build through Sparkle.

### P1 — Correctness debts users will hit (1.5–2 weeks, parallel with P2 start)

Selected from the two todo files for "silently wrong" or "data at risk", not polish.

| # | Item | Root cause (from todo) | Days |
|---|---|---|---|
| C-1 | Rename renames unrelated locals | `engine/rename.rs` buckets by per-file `in_definition_scope`; a `let record` beside `fn record` is renamed too. Filter by `RefKind` compatible with the definition's `ItemKind`, stamp `RenameFile` with the indexed hash. Also fixes the "N usages" over-count | 2 |
| C-2 | Background rename is not undoable | `RenameApply.applyBackground` assigns `textView.string`; route through `EditorHostView.replaceText`. Becomes a consumer of the edit plan (B-1) if B-1 lands first | 1 |
| C-3 | Whole-file parse-error underline flicker | `errors::collect` reports whole ERROR nodes; report the unexpected leaf tokens | 1 |
| C-4 | Auto-import dropped when typing continues | The import edit is discarded if the buffer changed before the engine replies; apply it against the current text | 1 |
| C-5 | Multi-project diagnostics and run configs | `DiagnosticStore.build` is one slot; run configs keyed by target name only; dropped-root diagnostics linger. Key all three by project root | 2 |
| C-6 | Debugger opens a second read-only buffer under symlinked roots | Match incoming frame paths through the resolved path like `source_path::same_file` | 0.5 |
| C-7 | Incremental reindex loses cross-crate glob re-exports | Return `None` from `delta` when a changed crate has cross-crate roots, or absorb them through `Deferred::targets` | 1 |
| C-8 | Per-session locks | One `RwLock<Inner>` serialises every keystroke against every query. `Arc<Mutex<BufferSession>>` per session. Engine-only, can run beside app cards | 3 |

### P2 — The two missing boundaries: edit plan and diff engine (2 weeks)

Both are prerequisites for the rest of Git, for AI Apply, and for local history. `level-up.md` section 4 planned them; they were skipped when Git landed on top of `git diff` text.

| # | Item | Notes | Days |
|---|---|---|---|
| B-1 | Edit plan | `EditPlan { files: [{ path, edits, expected_hash }], caret }` in the engine; one app-side apply path (validate against live text, one undo group per buffer, disk for closed files, skip and report on mismatch). Migrate rename, Safe Delete, refactorings, intentions and Generate onto it; this removes the remaining `textView.string` writers | 4 |
| B-2 | Diff engine | `src/diff/`: line and word diff, hunk model, three-way merge model. Git's diff view switches to it (word marks inside changed lines come free); rename and Replace in Project previews reuse it | 4 |
| B-3 | Diff view generalised | Today's `GitDiff*` views become a `DiffView` fed by the engine model, inline and side-by-side, used by Git, previews and AI Apply | 3 |

### P3 — Finish Git (2–3 weeks)

| # | Item | Notes | Days |
|---|---|---|---|
| G-1 | Gutter change markers and revert hunk | Engine diff of buffer text against the index blob; revert is an edit plan | 3 |
| G-2 | Stage and unstage hunks | From the diff view; `git apply --cached` with a hunk patch from B-2 | 2 |
| G-3 | History and blame | File and project log with diff; annotate in the gutter | 4 |
| G-4 | Stash and merge | Stash list/apply/pop; merge a branch; conflicted files listed in Problems | 2 |
| G-5 | Conflict resolver | Three-pane view on B-2's merge model | 4 |
| G-6 | Local history | Snapshot per save under the support folder, Show History with diff and revert | 3 |
| G-7 | Commit message from staged diff | AI, one button in the commit box (was 2.2-6); cheap once G-1..G-2 exist | 1 |

### P4 — Assistant that edits (2 weeks, can start after B-1/B-3)

| # | Item | Notes | Days |
|---|---|---|---|
| A-1 | Apply with diff preview | Chat code blocks get Apply: the reply becomes an edit plan previewed in `DiffView`, one undo group | 3 |
| A-2 | ⌘K inline edit | Instruction on a selection, reply parsed into edits, preview, refine/retry in the same thread | 3 |
| A-3 | Fix / Explain from a diagnostic | Problems panel and ⌥↩ gain Explain and Fix with AI; fix is an A-2 plan | 2 |
| A-4 | Local model provider | Ollama / MLX (OpenAI-compatible endpoint) as a provider; "keep everything local" preference. Raised from `level-up.md`'s low priority because there are no Anthropic credits | 2 |
| A-5 | Persisted threads | Chat threads saved per workspace | 1 |
| A-6 | Later | Generate tests and docs, read-only assistant tools loop, `@codebase` retrieval over the reference index, next-edit prediction | — |

### P5 — Finish the oracle (2–3 weeks)

| # | Item | Notes | Days |
|---|---|---|---|
| O-4 | Inlay hints | `textDocument/inlayHint` for the visible range after edits settle; drawn like code-vision labels | 4 |
| O-5 | Semantic highlighting | `semanticTokens/range` merged over tree-sitter spans for the visible range | 3 |
| O-7 | Oracle status and freshness | Status-bar badge for Failed/Unavailable, per-server status, rewrite clangd's compile-db copy when the project's database changes, start rust-analyzer when a Rust workspace opens | 2 |
| O-8 | Type-dependent refactorings | Extract Function, Change Signature (through the reference index, refuse on unresolved call sites), trait and base-class generators; all emit edit plans | 8 |
| O-6 | Live type errors | Skipped unless users ask; cargo and clang already check while typing | — |

### P6 — Debugging depth (`level-up.md` 2.3, 4–6 weeks)

Unchanged from `level-up.md` 3.6. Suggested internal order by daily value: 2.3-1 debug a test from its gutter marker, 2.3-8 breakpoints panel and inline values, 2.3-7 run/build ergonomics, 2.3-9 coverage gutter, 2.3-2 attach picker, 2.3-3 watchpoints, 2.3-4 memory view, 2.3-5 assembly, 2.3-6 core files, 2.3-10 Instruments hand-off. Also carry the debugger debts: `debugLaunch` off the main thread with the engine emitting `Running`, pause mapped to a pause state, exception filters reaching a live session.

### Continuous — engineering debt (one card per tier, picked when its file is touched)

From `todo/engine/remaining.md` "Structure" and "Full review": Rust outline re-parses the whole buffer per edit; Markdown reparses from scratch per keystroke; bracket matching scans all strings and comments per caret move; three `use`-tree parsers; `InputEditFfi` trusted as sent; `caret_byte` pre- vs post-edit meaning; `Engine::read/write` infallible `Result`s; duplicated outline builders and declarator walkers. Per `AGENTS.md`, these are done when their module is opened for feature work, not as a separate release.

Polish items (popup stack planner, outline nesting for Markdown and C++ out-of-class methods, per-buffer line endings, Find in Project grouped per line, bottom-panel heights keyed by an enum, AI chat empty state) are Tier-A filler between cards.

## 3. Decisions for review

| # | Question | Recommendation |
|---|---|---|
| D-1 | Version of the first public tag | Tag **1.1.0** from current `main` (1.0.0 content plus AI, Git, oracle), renaming "Unreleased" to 1.1.0; a 1.0.0 tag nobody installed adds nothing. Alternative: tag 1.0.0 at `a7af69c` for history, then 1.1.0 immediately |
| D-2 | Git vs assistant vs oracle order after P0–P2 | Git first (P3): it is half-built and the daily loop still leaves the app for history and conflicts. Assistant Apply (P4) next because it reuses P2 directly. Oracle polish (P5) after |
| D-3 | Local model priority | Raise to P4 (A-4) given no Anthropic credits and the KD-21 local-first rule |
| D-4 | Multi-caret / column selection | Still cut; revisit after first user feedback from P0 |
| D-5 | Live type errors (O-6) | Drop unless requested |

## 4. Rough calendar

| Weeks | Work |
|---|---|
| 1 | P0 ship |
| 2–3 | P1 correctness (C-8 in parallel as engine-only), start B-1 |
| 3–5 | P2 edit plan, diff engine, diff view |
| 5–8 | P3 Git |
| 8–10 | P4 assistant that edits |
| 10–13 | P5 oracle finish |
| 13+ | P6 debugging depth |
