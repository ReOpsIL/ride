# Follow-ups after E6 / A7 / A9

- A8 project-wide symbol search (`Cmd+Shift+R`)
- E7 notify + safe tar (post-1.0)

# Found 2026-09-09 (see plan/roadmap/improve-extend.md)

- index: prune old `gen-*` after manifest bump and on engine start
- index: skip reindex when crate-set fingerprint matches the live manifest
- status: replace sticky `message` with `phase` + `warnings` count; log crate errors separately
- discover: sysroot scan limited to std/core/alloc and their members; real sysroot version
- query: golden ranking tests; single-hit results for `coun`, `Has`

# Found 2026-09-09 (ranking probes)

- extract: `pub mod` re-exports such as `std::option` and `core::primitive::str` are labeled `fn`; check the module item kind in reexport/apply
- query: `crate_prefix` still uses a regex sample; move it to the name_prefix term path
