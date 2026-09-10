# App follow-ups (see plan/roadmap/improve-extend.md)

- A3 split: EditorJump is a singleton bound to the last-attached pane; rework before adding a second pane
- auto-`use` on completion accept (needs an import-path field on hits)
- Sparkle or manual update check (Phase 5)
- universal (x86_64) xcframework slice (Phase 5)
- Outline shows occasional blank rows on large files (items with empty names); filter or name them
- TOML highlighting for Cargo.toml (add a tree-sitter-toml Syntax the same way as markdown)
- Format on save stays Rust-only; extend to C/C++ once a missing `clang-format` degrades silently instead of surfacing an error on every save
- Save panel defaults untitled buffers to `.rs`; offer `.c` / `.cpp`
