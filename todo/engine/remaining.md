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

- cheatsheet: no sheets for TOML (Cargo manifest keys) and CMake yet; `Lang::Toml` / `Lang::Cmake` answer with no sections
- context: detection is syntactic; `expression` after `x.` does not know the type of `x`, so iterator and string sections rely on the typed prefix
- context: C `switch` bodies and Rust `match` arm blocks classify by the generic brace rules; a `case` label context could offer `case`/`default` templates first
- Test markers: `src/run/tests/markers_cpp.rs` has no comment tracking, so a `TEST(...)` inside `/* */` yields a gutter marker; add the block-comment scan from `markers.rs` and a `tests/test_markers.rs` case.
