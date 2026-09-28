# Follow-ups after E6 / A7 / A9

- A8 project-wide symbol search (`Cmd+Shift+R`)
- E7 notify + safe tar (post-1.0)

# Found 2026-09-09 (see plan/roadmap/improve-extend.md)

- index: prune old `gen-*` after manifest bump and on engine start
- index: skip reindex when crate-set fingerprint matches the live manifest
- status: replace sticky `message` with `phase` + `warnings` count; log crate errors separately
- discover: sysroot scan limited to std/core/alloc and their members; real sysroot version
- query: golden ranking tests; single-hit results for `coun`, `Has`

# Open after 2026-09-09

- extract: re-exports from non-sysroot crates (e.g. a workspace crate re-exporting a dependency item) still fall back to a guessed kind; extend External to direct deps if it matters
- index: ~440 MB per generation for 1.58M docs; audit stored fields (source_chunk is stored and unused by the app)
- engine: replace the 250 ms manifest poll with an FSEvents-driven reload
- query: in-app completion for `Has` ranked a cache crate's exact `has` method above the `Hash` trait while the CLI does not; compare the app's query (context, current_crate) with the CLI's

# C / C++ (added 2026-09-10)

- check: `run_check_c` is per saved file; a header edit does not re-check the sources that include it, and there is no whole-project C check (`compile_commands.json` walk)
- highlight: the include walk follows both branches of an `#if`, so libc++'s frozen `__cxx03/` copies share the 512-file system budget with the live headers; evaluate `__cplusplus`-style guards or skip `__cxx03/` if `std::` names go missing
- highlight: range-for over a template container (`for (auto &s : shapes)`) and iterator results stay on the field-name fallback; element typing needs template-argument tracking in the `TypeTable`

# Languages (added 2026-09-10, see plan/roadmap/next.md 1.1-9)

- highlight: an extension-less libc++ header (`memory`, `vector`) opened as a buffer gets no language (`Lang::for_path` falls back to Rust, the app to plain) although `headers.rs::load_system` already parses it as C++; sniff by system include directory or C++ markers in `Lang::for_buffer`

# Cheat sheet (added 2026-09-10, see plan/roadmap/cheatsheet.md)

- context: a `where` clause between a signature and its `{`, a generic parameter list after an item name, a format string literal, and a `#[test]` body have no context of their own (see plan/roadmap/cheatsheet.md Limits); a dedicated context would let their sections stop using `contexts = []`
- cheatsheet: an entry can list several contexts but a C++ member template belongs in both `item` and `fields`; consider letting one file be registered under two titles, or a `contexts` override per entry
- lookup: `std::` and `[` end the word, so the prefix is empty until the user types past them; consider treating `::`-qualified names as one word for matching
- context: detection is syntactic; `expression` after `x.` does not know the type of `x`, so iterator and string sections rely on the typed prefix
- context: C `switch` bodies and Rust `match` arm blocks classify by the generic brace rules; a `case` label context could offer `case`/`default` templates first
- Test markers: `src/run/tests/markers_cpp.rs` has no comment tracking, so a `TEST(...)` inside `/* */` yields a gutter marker; add the block-comment scan from `markers.rs` and a `tests/test_markers.rs` case.

# Audit follow-ups (2026-09-17)

- Incremental reindex (`src/index/incremental.rs`) re-extracts changed crates with `External::default()`, so cross-crate glob re-exports mirrored by the full build vanish until a forced rebuild. Absorb the cross-crate roots for changed crates via `Deferred::targets`, or return `None` from `delta` so the full build runs.
- Rename (`src/engine/rename.rs`) buckets hits by `in_definition_scope`, which is per file, while `refs/rust.rs` records every identifier; a local `let record = 1;` in the definition file is renamed together with `fn record`. Filter the auto bucket by `RefKind` compatible with the definition's `ItemKind` (`RefKind::from_label` is unused today) and stamp `RenameFile` with the indexed file hash.
- Duplicated shapes to fold: outline item builder across `c_outline`/`c_types`/`c_scopes`/`cmake_outline`/`make_outline`/`rust_types`; C declarator walkers; C doc-comment extraction (`c_docs.rs` vs `engine/doc_comment.rs`, adjacency rules already drift); compile_commands entry load; DAP framing shared with `fake_dap`.
- `index/status.rs` `status.jsonl` is append-only and re-read every 250 ms by the watcher; `refs/index.rs` has no schema version; `debug/transport/frame.rs` allocates `Content-Length` bytes uncapped.

# Refactor (added 2026-09-20, 1.3-6b review)

- refactor: Introduce Constant anchors at the item node, so a `const` lands between a doc comment or attribute and its item; anchor above the contiguous run of `line_comment`/`attribute_item` siblings that precede the item.
- menus: Inline Variable is ⌃⌥N because ⌥⌘N is New Buffer; decide whether New Buffer moves so the JetBrains chord can be used.


# Multi-project indexing (2026-09-23, see docs/product/multi-project.md)

- A folder that is not a Cargo project is indexed as one plain crate named after the folder (`index/crates.rs` `plain_workspace`), so nested crates' items get the folder's crate name and wrong module paths, and their dependencies are not scoped as direct. Run `load_metadata` on each nested Cargo root from `project::project_roots`, add their packages as workspace crates, and exclude those roots from the plain folder walk.

# Definitions (2026-09-27, enum variant Quick Definition review)

- `find_definitions` returns a workspace file's own items twice, once as a local hit (`source_path` None) and once from the index (`source_path` set). `quick_definition` hides this by deduping on the loaded path, but Go to Definition lists both. Give local hits the session path, then dedupe on `(source_path, name_byte)`.
- Struct fields have no definition source: `c.v` needs the receiver type (`rust_receiver`, C member chains) to resolve the owner, then the owner's `Field` members from the type table.
- Rust variants imported by a `use` in another module file resolve only through the index; `rust_use_variants` covers enums declared in the same buffer.

# Structure (2026-09-27, full code review)

- One `RwLock<Inner>` guards every session: each keystroke's `apply_edit` (reparse, highlights, outline) holds the global write lock and blocks queries on other buffers. Move sessions behind per-session locks (`Arc<Mutex<BufferSession>>`) and keep `Inner` for shared state.
- The Rust outline re-parses the whole buffer on every edit: `grammar/rust.rs` `outline` ignores the tree it is given and calls `rust_outline::from_source` → `extract_source`. Add an `extract` entry point that takes a parsed tree and use it from the outline.
- `Syntax` has 25 methods and `tree_syntax.rs` is mostly `tree.as_ref()?` plus a free-function call. Expose `tree()`/`grammar()` and move the dispatch into `session_queries.rs`.
- `InputEditFfi` is trusted as sent: `edit.rs` checks bounds but not `new_end_byte == start + inserted.len()` or the row/column points. Derive the new end and points in the engine from the replica and the inserted text, and shrink the FFI record.
- Markdown reparses the inline tree and up to six fence grammars from scratch per keystroke (`markdown.rs`, `fences.rs`); apply the edit and reparse incrementally.
- Bracket matching collects every string and comment in the file on each caret move (`editing/brackets.rs`); use the bracket token's ancestors instead.
- Three `use`-tree parsers: `rust_use_variants`, `extract/use_walk.rs`, `imports.rs` + `site/use_path::leaf_names` (text tokenizer). Extract one use-tree visitor.
- Boundary-floor loops are copied in `bin/ride_engine/cursor.rs`, `highlight/header.rs`, `check/output.rs`, `check/fmt_rust.rs`, `check/fmt.rs`; use `highlight::offset::floor_char`.
- `Engine::read`/`write` return a `Result` that can never be `Err`; the `catch_unwind(read(sessions.get(id).map(f)).ok().flatten())` shape repeats ~15 times. Return `T` and share one session-query helper.

# Full review follow-ups (2026-09-27)

- `caret_byte` means different things across edits: rustc/clang fixes and generate use pre-edit positions, intentions post-edit. Pick one meaning (post-edit) and convert at the producers.
- `intentions` `Draft` drops the ExtractPlan name selection, so Extract Variable from the lightbulb does not select the new name.
- `last_status` still reads all of `status.jsonl`; the poll now skips unchanged files, but a changed file is read whole. Seek to the tail.
- Quick-doc HTML: `doc_html` copies the markdown parser options; expose them from `markdown`. Also drop `javascript:` link targets.
- Signature help still matches same-file hits by name only; order them with `local_defs` like go-to-definition.
- Named re-exports of dependency crates (not only std) stay unresolved in workspace crates, which are built before their dependencies; std/sysroot is now built first.
- A re-export of a whole module (`pub use core::option;`) does not bring the module's children, so `std::option::Option` resolves only through the sysroot path.
- Generate for Rust still drops generics and lifetimes (`struct W<T>` → `impl W`): `GenType` carries no generics; add them where `engine/generate.rs` builds it. `generate::apply` has no language parameter, so a direct C call still emits C++.
- `refactor/local.rs` and `highlight/rename_local.rs` both define `ident_at`/`enclosing_scope`/`SCOPE_KINDS`; make the highlight versions `pub(crate)` and delete the refactor copies.
- Over 40 lines: `index::build::run`, `query::children::run`, `query::items::item_search`, `extract::walk_item`. Over 200 lines: `tests/intentions.rs`, `tests/refs.rs`.

# Semantic oracle (added 2026-09-28, see docs/product/semantic-oracle.md)

- oracle: only member lists come from rust-analyzer; hover, definition, inlay hints and type info (2.1-5) and live type errors (2.1-6) still use heuristics
- oracle: clangd sidecar for C and C++ (2.1-3) behind the same `Oracle`; `Sidecar` is rust-analyzer specific in its init options and item mapping
- oracle: status bar badge for `Failed`/`Unavailable`; today the state shows only in Preferences
- oracle: two sessions on the same path would both `didOpen` the same URI; key open documents by URI if split panes ever get separate sessions per file
- oracle: `Vec::new().` style identifier and path completions (`Site::Identifier`, `ScopedPath`) still come from the catalog; decide per site whether rust-analyzer should win
- oracle: the first answer after a cold start takes ~1–3 s on a small crate; measure on a large workspace and consider starting the sidecar when a Rust workspace opens instead of on the first dot
