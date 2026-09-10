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

- check: no diagnostics for C/C++; a `compile_commands.json`-driven `clang` run (or `clangd`) would fill the Problems panel the way `cargo check` does
- highlight: `.h` is always C; sniff the header for `class`/`namespace`/`template` and open it as C++ when found
- highlight: C/C++ definitions are buffer-only; index `#include` targets found on the include path for cross-file jumps
- highlight: C++ completion has no member-access awareness (`obj.` lists all buffer identifiers)
