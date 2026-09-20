# Ride — Level-up plan (2026-09-20): from a fast editor loop to the native IDE for Rust and C/C++ on the Mac

| Field | Value |
|---|---|
| Baseline | `main` = `grok/next-impl` at `b014dfa` (1.1, 1.2 and most of 1.3 landed); 410 engine tests green; `MARKETING_VERSION` 0.1.0; no git tag, no public release |
| In flight (uncommitted) | AI suggestions in the completion popup and Ask AI from Comment (`app/Ride/AI/`, `docs/product/ai-complete.md`), New Project scaffold (`app/Ride/Project/`), a preferences store split |
| Size | Engine ~27k LOC Rust in 19 modules, app ~27k LOC Swift in 25 folders, 1,900 cheat-sheet templates, 3 sample projects, 44 engine test binaries, 60 RideTests files, 28 demo scenes |
| Principle kept | Swift shell, Rust engine, sub-millisecond keystroke path, index what is on disk, refuse rather than guess |
| Principle revisited | KD-6 (no rust-analyzer / clangd) and the 1.0 "no AI" non-goal, both as explicit decisions below |
| Horizon | 1.3 close-out · **1.0 public** · 2.0 Git · 2.1 Semantic oracle · 2.2 Assistant · 2.3 Debugging depth and assembly |

## 1. Where Ride stands

### 1.1 What it is

A native macOS IDE for Rust with C and C++ as peers, plus TOML, Make, CMake and Markdown as supporting languages. A SwiftUI/AppKit shell over an in-process Rust engine (UniFFI) that discovers every crate on disk including the sysroot, extracts items with tree-sitter, indexes them in Tantivy (about 1.7M documents, 900 MB live) and answers completion, highlight, outline, definition and documentation queries in under a millisecond. Builds, runs, tests and debugs through the real toolchains (`cargo`, CMake File API, `make`, `compile_commands.json`, `lldb-dap`). No LSP, no cloud model in the keystroke path.

### 1.2 Feature map

Status: **shipped** (live, verified), **built** (implemented, not verified end to end on that language), **partial**, **none**.

| Area | Shipped | Built or partial | None |
|---|---|---|---|
| Editor | TextKit 2 buffer, tabs, split panes, smart Enter/Tab, comments, bracket pairing, line ops, extend selection, folding, Surround With, snippets with stops, format on save (rustfmt, clang-format, taplo, cmake-format, Makefile), persistent workspace state, light and dark themes, design tokens | fold chevrons, bracket-pair highlight (todo) | multi-caret, column selection, sticky headers |
| Completion | six sites, buffer + workspace + catalog, `use` and `#include` paths, typed members after `.`/`->`/`::`, struct-literal fields, attributes, postfix, call snippets, auto-import, signature help, ranking goldens in CI | AI suggestions merged into the popup (in flight) | members of call results, generics and templates, trait methods, argument-position ranking, closures (1.4) |
| Navigation and docs | quick open, symbol search, project find and replace, go to definition into buffer/header/crate, hover, Quick Documentation with intra-doc links, Quick Definition peek, back/forward, recent files, header/source switch, outline, cheat sheets for 6 languages | | breadcrumbs and bookmarks (cut on purpose) |
| Diagnostics | parse errors, `cargo check`/clippy on save and live, clang `-fsyntax-only` live over stdin, clang-tidy on save, whole-project C check, Problems panel with owners, lint doc links | | intention actions / quick fixes (1.3-5) |
| Build, run, test | Cargo, CMake, Make, compile-db project models; targets panel; run configs with sanitizers; run console with links; single-file run; Recompile File; terminal (SwiftTerm); cargo, GoogleTest, Catch2, CTest runners; gutter markers; Tests panel | C and C++ paths built, only C++ single-file run verified live; CMake profile picker does not re-detect | coverage, profiling hand-off |
| Debug | lldb-dap launch, line/conditional/hit-count breakpoints, step, frames, locals with Rust formatters, watches, evaluate, hover values, Debug panel | C++ formatters, exception and panic breakpoints, attach types in protocol only | attach UI, watchpoints, memory view, disassembly, core files, debug-a-test, breakpoints panel |
| Understand and change | reference index and Find Usages, rename (inline and workspace preview with safe apply), Generate for C++ and Rust field code, Extract Variable | code-vision "N usages" model without a view | intentions, Introduce Constant, Inline, Safe Delete, Extract Function, Change Signature, semantic highlighting, inlay hints, Type Info, call and type hierarchy, base-class and trait generators |
| Git | dirty badges in the tree | | changes, commit, history, blame, branches, conflicts, local history (2.0) |
| AI | | completion suggestions and Ask AI from Comment with Anthropic account, API key or OpenRouter, five context levels (in flight) | inline edit, fix-from-diagnostic, explain, tests and docs generation, local model |
| Distribution | `release.sh` archive, sign, notarize, Sparkle appcast, universal xcframework, `install.sh`, screenshots script | no tag, no appcast published, no cask, no site | crash reports, onboarding, CLI launcher |
| Process | delegated cards with tiers and gates, self-test scene (91 Rust + 32 C++ steps), goldens, CI (fmt, clippy, test, engine build, xcodebuild test, selftest) | latency gate, index-size audit (todo) | |

### 1.3 What is unusual and worth protecting

1. The keystroke path answers from everything on the machine in under a millisecond, with nothing to install and no language server to babysit.
2. Cheat sheets: a second popup that teaches the language at the caret; nothing comparable exists in RustRover or CLion.
3. C, C++ and Rust as peers in one small app, from `compile_commands.json` to `lldb-dap`.
4. The engineering process: every card ships with gates re-run by the reviewer, self-test steps that run without UI automation, ranking goldens. This is what lets a small team move fast without a QA team.

### 1.4 What holds it back

1. **Heuristic types have a ceiling.** `foo().bar`, iterator chains, generics, trait methods and macro-generated items are all "unknown". 1.3-7 and 1.4 push the heuristics three hops further and then stop. RustRover users judge an IDE by whether `.` after an iterator chain completes.
2. **Nothing has shipped.** 0.1.0, no tag, no appcast, no page. Every feature since 1.0 has one user.
3. **No Git.** The daily loop still leaves the app to commit.
4. **The C and C++ story is built but unproven live.** The inventory lists it honestly; users will not read the inventory.
5. **Data-safety debts** in `todo/app/remaining.md`: breakpoints do not shift with edits, whole-text replacement (format, reload, replace in project) clears undo, stale highlight spans after re-attach.
6. **AI arrived without a decision.** The 1.0 spec forbade it, the tree now contains 1,200 lines of it. Either it is a product pillar with a design, or it is an experiment. Section 6 decides.

## 2. The five bets

The next level is not more features of the same kind. It is these five moves, in this order of leverage:

| Bet | What changes for the user | Why Ride can do it better than the incumbents |
|---|---|---|
| **B1 Ship 1.0** | Ride is something a Rust developer can install from a cask, keep updated and trust with their project | The polish work is small; the self-test, goldens and screenshots pipeline already exist |
| **B2 Git and history** | The whole daily loop stays in one window | Diff engine shared with rename preview, local history and AI edits (section 4) |
| **B3 Semantic oracle** | Types are true, not guessed: `counter.iter().map(\|x\| x.` completes, inlay hints are right, borrow errors appear while typing | rust-analyzer and clangd are already on disk (rustup component, Xcode); Ride keeps its sub-ms path and uses the oracle only off the hot path, cached into the `TypeTable` |
| **B4 An assistant that uses the IDE's index** | AI edits arrive as a previewed, undoable plan built from precise context: the definitions, usages and signatures Ride already knows, not 100k characters of files | No other IDE has a sub-ms local catalog plus a reference index to build context from; local models become viable because the context is small |
| **B5 Depth on the native-app loop** | C++ debugging verified live, debug a test, watchpoints, memory, disassembly, assembly files, coverage gutter, Instruments hand-off | Everything is a `lldb-dap` request or a toolchain JSON output; the session and panel infrastructure is in place |

## 3. Releases

Days are engineer days at the card cadence of `next-impl.md` (one card, one branch, gates re-run by the reviewer). Tiers: A delegate freely, B delegate with the design followed literally, C strong model.

### 3.1 Release 1.3 close-out — Understand and change (3–4 weeks)

Finish what is open before starting anything new; half-finished refactoring menus erode trust faster than missing ones.

| # | Feature | Design notes | Tier | Days |
|---|---|---|---|---|
| 1.3-6b | Introduce Constant, Inline, Safe Delete | Same engine shape as Extract Variable: one node in, edits out, refuse otherwise; Safe Delete checks the reference index and refuses with the usages listed | B | 4 |
| 1.3-5 | Intention actions (⌥↩) | One light-bulb menu: compiler `suggested_replacement` and clang fix-its, add `use` / `#include`, `_` prefix, missing `match` arms, the refactorings that fit the selection | B | 5 |
| 1.3-8 | Call and type hierarchy | From the reference index and the `TypeTable`; side panel; ⌃⌥H and ⌃H | B | 4 |
| 1.3-1e | Code vision "N usages" | The `UsageVision` model exists; draw the overlay in `RideTextView` line fragments | B | 2 |
| 1.3-2d | Self-test reference-index isolation | Fresh refs dir per demo launch | A | 1 |
| DS-1 | Data-safety fixes | Breakpoints shift with edits and re-sync; whole-text replacement goes through the undoable path; highlight spans shift or drop on edit | B | 3 |
| DS-2 | `RideEngineClient.withEngine` | Replace the 17 copies of the engine prologue | A | 1 |

Deferred from 1.3 to 2.1: 1.3-7 semantic highlighting, inlay hints and Type Info, 1.3-4c base-class and trait generators, Extract Function and Change Signature. All four need real types; building them on heuristics and rebuilding them on the oracle is double work.

Exit: every Code and Refactor menu item either works or is absent; ⌥↩ on a cargo error applies its suggestion; the three audit data-loss bugs have tests.

### 3.2 Release 1.0 public — Ship it (3 weeks)

The version number goes to 1.0 because the product already exceeds the 1.0 spec. This release is polish, packaging and onboarding, not features.

| # | Feature | Design notes | Tier | Days |
|---|---|---|---|---|
| P-1 | Release train | Tag `v1.0.0`; `CHANGELOG.md` from the card log; `release.sh` runs in CI on a tag and publishes the zip, dSYM and appcast to GitHub Releases; Sparkle checks the published appcast; Homebrew cask in a tap | A | 3 |
| P-2 | Onboarding | Welcome view checks and offers to fix: Xcode Command Line Tools, rustup and `rust-src`, cmake/clang-format/taplo (the Tools installer exists), developer mode for debugging; a "first project" path opens `samples/rust-demo` copied to a chosen folder | B | 3 |
| P-3 | Crash and panic reports | Engine panics and app crashes written to the support directory with a notice on next launch and a Copy Report action; no telemetry | A | 2 |
| P-4 | `ride` CLI launcher | `ride .`, `ride path/to/file.rs:12`, installed from the app menu to `/usr/local/bin`; opens or focuses the workspace | A | 1 |
| P-5 | C and C++ live verification | The C++ debug self-test on `samples/cpp-demo` (stop in `Circle::area`, expand a `std::vector`, step out, `cpp_throw` filter) and a C one on `samples/c-demo`, in CI with developer mode enabled; GoogleTest and Catch2 through the sample's CMake binaries | A | 3 |
| P-6 | Editor leftovers users hit first | Fold chevrons in the gutter, bracket-pair highlight, Reformat Selection, CRLF to LF preference, ⌫ and ↩ in the tree, New File language picker | A | 4 |
| P-7 | Site and docs | One page under `docs/site/` built from the README screenshots (`screenshots.sh` already regenerates them), a manual under `docs/manuals/` generated from the shortcut list (⌘? already has it), the three sample READMEs as tutorials | A | 2 |
| P-8 | Hygiene gates | Latency gate in CI (completion p95 under 5 ms per site, editor queries under 1 ms), index-size audit, a file-size check that fails CI on a source over 220 lines (15 files today) | A | 2 |

Exit: a stranger installs Ride from the cask, opens a Cargo project, gets completions, runs tests, hits a breakpoint and receives the next update through Sparkle.

### 3.3 Release 2.0 — Git and history (4–5 weeks)

As planned in `next.md`, with one structural addition: the diff engine is a shared engine module used by four features.

| # | Feature | Design notes | Tier | Days |
|---|---|---|---|---|
| 2.0-0 | Diff engine | `src/diff/`: Myers with line and word granularity, hunk model, three-way merge model; `DiffView` in the app with side-by-side and inline modes, syntax highlighted through the engine; reused by rename preview, replace preview, local history, AI edits | C | 5 |
| 2.0-1 | Changes and commit | Diff gutter markers per buffer with revert hunk; Changes panel with stage, unstage, commit, amend; commit message editor next to the diff; `git` CLI only | B | 6 |
| 2.0-2 | History, blame, branches | File and project log with diff; Annotate in the gutter; branch create, checkout, merge; stash | B | 5 |
| 2.0-3 | Conflicts | Three-pane resolver; conflicted files in the Problems panel | B | 4 |
| 2.0-4 | Local history | Snapshot per save under the support directory, five working days, Show History with diff and revert | A | 3 |

Exit: edit, review the hunks, commit and push without leaving the window; a merge conflict resolves in the three-pane view.

### 3.4 Release 2.1 — Semantic oracle (6–8 weeks)

The decision is KD-20 in section 6. The design keeps every principle that matters: the keystroke path never waits on the oracle, the oracle runs isolated like the indexer, and Ride works fully without it.

| # | Feature | Design notes | Tier | Days |
|---|---|---|---|---|
| 2.1-1 | Oracle boundary | `src/oracle/`: a `SemanticOracle` trait (`type_of(file, byte)`, `resolve(file, byte)`, `members_of(type)`, `hints(file, range)`, `diagnostics(file)`); `Heuristic` implementation wraps today's `TypeTable`; `Facts` cache keyed by file hash and byte range that the `TypeTable` consults first. Completion reads the cache only, never the oracle | C | 6 |
| 2.1-2 | rust-analyzer sidecar | Child process over stdio (`rust-analyzer` from the rustup component, discovered like `rust-src`), LSP client in `src/oracle/lsp/` limited to `initialize`, `didOpen/didChange`, `hover`, `definition`, `inlayHint`, `completion` (for member lists only) and `publishDiagnostics`; results feed `Facts`; a crash or a 2 s timeout falls back to heuristics silently and shows a status-bar badge | C | 8 |
| 2.1-3 | clangd sidecar | The same client against `xcrun --find clangd` with the compile database; C and C++ get the same facts | B | 4 |
| 2.1-4 | Completion that knows types | The 1.4 items (`foo().bar`, generics, trait methods, closures, argument position) implemented as `Facts` consumers: when a fact exists it wins, otherwise the heuristic answers as today; goldens grow to cover both paths | B | 6 |
| 2.1-5 | Semantic highlighting, inlay hints, Type Info | 1.3-7 on facts: locals, parameters, fields and types coloured; type hints after `let` and `auto`, parameter hints in calls; ⌃⇧P says the type or "unknown" | B | 6 |
| 2.1-6 | Type errors while typing | Oracle diagnostics into the live owner of `DiagnosticStore`; cargo and clang checks stay as the source of truth on save | A | 2 |
| 2.1-7 | Base-class and trait generators, Extract Function, Change Signature | 1.3-4c and the two Tier-C refactorings on resolved types; Change Signature updates call sites through the reference index and refuses on unresolved ones | C | 8 |

Exit: `totals.iter().map(|(name, total)| name.` completes `&str` methods with the oracle on and falls back cleanly with it off; inlay hints are right on the samples; a borrow error appears within two seconds; completion p95 stays under 5 ms in both modes.

### 3.5 Release 2.2 — Assistant (5–6 weeks)

Builds on the in-flight AI work and on the diff engine. Every AI edit is a plan previewed in the diff view and applied through the undoable path; nothing is written blind.

| # | Feature | Design notes | Tier | Days |
|---|---|---|---|---|
| 2.2-1 | Context packs from the engine | Move context assembly from `AIContextBuilder.swift` into `src/ai/context.rs`: the enclosing item, definitions of every referenced symbol (catalog signature plus first doc paragraph), usages of the item under the caret, the current diagnostics, sized by a token budget; the five context levels become budgets, not file dumps | C | 5 |
| 2.2-2 | Inline edit (⌘K on a selection) | Instruction sheet, reply parsed into edits, previewed in the diff view, applied as one undo group; refine and retry keep the thread | B | 4 |
| 2.2-3 | Fix and explain from a diagnostic | Problems panel and the ⌥↩ menu gain Explain and Fix with AI; the fix is a 2.2-2 plan; the explanation opens in the AI panel | B | 3 |
| 2.2-4 | Generate tests and docs | Gutter and Code menu actions: tests for the item under the caret into the right module or file, a doc comment from the signature and body; both previewed | B | 3 |
| 2.2-5 | Local model provider | Ollama and MLX endpoints as a fourth provider; a preference to keep everything local; the context packs make 7B-class models useful | A | 2 |
| 2.2-6 | Commit messages | With 2.0: Generate from the staged diff | A | 1 |
| 2.2-7 | Assistant tools | The AI panel can call read-only engine tools (find definitions, find usages, read file, run tests) in a bounded loop with every call shown; no writes outside a previewed plan | C | 6 |

Exit: select a function, ask for an error type instead of `unwrap`, review the diff, apply, undo; Fix with AI on a clippy warning applies a correct plan; the same flows work against a local model.

### 3.6 Release 2.3 — Debugging depth and assembly (6–8 weeks)

`next-1.3.md` release 1.5 as written, minus P-5 (moved into 1.0 public), plus two native-app items the earlier plan excluded.

| # | Feature | Tier | Days |
|---|---|---|---|
| 2.3-1 | Debug a test from its gutter marker | B | 4 |
| 2.3-2 | Attach to process with a picker | B | 3 |
| 2.3-3 | Watchpoints | B | 3 |
| 2.3-4 | Memory view | B | 4 |
| 2.3-5 | Assembly: tree-sitter grammar for `.s`/`.S`/`.asm`, disassembly view, instruction stepping, registers, Show Assembly for a function | C grammar and view, A the rest | 8 |
| 2.3-6 | Core files and crash log symbolication | A | 3 |
| 2.3-7 | Run and build ergonomics: CMake profile re-detect, test binaries as targets, `.env`, before-run build, ASan reports into Problems | B | 4 |
| 2.3-8 | Breakpoints panel, frame filtering, value formatting, inline values on the stopped line | A | 4 |
| 2.3-9 | Coverage gutter | `cargo llvm-cov --json` and `llvm-cov export` for CMake targets built with `-fprofile-instr-generate`; per-line marks and a per-file percentage in the Tests panel | B | 4 |
| 2.3-10 | Profile in Instruments | Debug ▸ Profile builds with symbols and hands the binary to `xctrace` with the Time Profiler template; no in-app profiler UI | A | 1 |

Exit: as in `next-1.3.md` 1.5, plus a coverage run on `samples/rust-demo` marks the untested lines of `util.rs`.

## 4. Architecture changes

Four boundaries make the releases above composable instead of accretive.

| Boundary | Module | Used by |
|---|---|---|
| **Edit plan** | `src/engine/edits.rs` grows into `EditPlan { files: [{ path, edits, hash }], review, caret }` with one app-side apply path (validate against live text, undoable through the pane host, disk for closed files, skip and report on mismatch). This is the rename safe-apply generalised | rename, refactorings, intentions, Generate, AI edits, revert hunk |
| **Diff engine** | `src/diff/` and `DiffView` | rename and replace previews, Git, local history, AI edits |
| **Semantic oracle** | `src/oracle/` trait, `Facts` cache, sidecar client; `TypeTable` consults facts first | completion, highlighting, hints, Type Info, generators, refactorings |
| **Context packs** | `src/ai/context.rs` | completion suggestions, inline edit, fix and explain, tests and docs, assistant tools |

Isolation rules stay as KD-15: the oracle sidecars are child processes the engine talks to over stdio; a dead sidecar is a status badge, never a hang. Nothing in this plan touches the keystroke path's contract (buffer replica, highlight deltas, sub-ms completion from the cache).

## 5. Process level-up

The card process works. Three additions keep it working at the scale of sections 3.4 and 3.5:

1. **Release train.** `main` merges at every release exit, tagged; `CHANGELOG.md` is the card log; CI publishes on tags. Today `main` only mirrors the working branch.
2. **Gates that measure.** Latency p95 per site and index size become CI numbers with thresholds, not todo items. The file-size rule becomes a CI check.
3. **Live verification per language.** The inventory's "built" column shrinks to zero for C and C++ before 1.0 public (P-5) and every later debugging card adds a self-test step on both `samples/cpp-demo` and `samples/rust-demo`.

## 6. Decisions to take before starting

| Decision | Recommendation | Consequence if declined |
|---|---|---|
| **KD-20 Semantic oracle** (revisits KD-6) | Adopt: opt-in sidecars for rust-analyzer and clangd behind the `SemanticOracle` trait; heuristics stay the default and the fallback; the keystroke path never waits | Continue with 1.4 heuristics: three-hop typing, standard containers only, "unknown" everywhere else; 2.1-5 and 2.1-7 stay heuristic and fragile |
| **KD-21 AI scope** (revisits the 1.0 non-goal) | Adopt as a pillar with three rules: off by default, never in the keystroke path, every edit previewed and undoable; local-first providers are first class | Keep the in-flight work as an experiment behind a preference and skip 2.2 |
| **KD-22 1.0 definition** | 1.0 is section 3.2's exit criterion, shipped before Git; version jumps from 0.1.0 to 1.0.0 | Git first pushes the first public build out by five weeks with no user feedback on the loop that exists today |
| **KD-23 Intel** | Ship the universal build CI already produces, untested on Intel hardware, marked as such in the release notes | Apple Silicon only, one fewer support surface |
| **KD-24 Sequence** | 1.3 close-out → 1.0 public → 2.0 Git → 2.1 oracle → 2.2 assistant → 2.3 debugging | Any reorder is fine except starting 2.2 before 2.0 (it needs the diff engine) or 2.1-4/5/7 before 2.1-1/2 |

## 7. Still cut

Find Action palette, breadcrumbs, bookmarks, TODO panel, plugin surface, macro expansion view, multi-root and remote workspaces, Vim mode, Meson or Gradle models, GitHub PR client, a model in the keystroke path, an in-app profiler UI, Valgrind, embedded and kernel targets. Multi-caret and column selection are the one editor feature worth reconsidering after 1.0 public, on user demand.

## 8. Next step

Commit the in-flight AI and New Project work (it is documented and the gates are green), write the 1.3 close-out cards in `next-1.3.md` style starting with DS-1 and 1.3-6b, and open `plan/roadmap/release-1.0.md` with the P-1 to P-8 cards so 1.0 public can start the week 1.3 closes.
