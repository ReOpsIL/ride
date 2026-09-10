# App follow-ups (see plan/roadmap/improve-extend.md)

- A3 split: EditorJump is a singleton bound to the last-attached pane; rework before adding a second pane
- Snippet mode ends when a nested completion is accepted inside a placeholder and that hit is itself a snippet (the outer stops are dropped)
- Signature help hides on any `)`; inside nested calls the outer signature only returns on the next `,`
- Sparkle or manual update check (Phase 5)
- universal (x86_64) xcframework slice (Phase 5)
- Outline shows occasional blank rows on large files (items with empty names); filter or name them
- New File in the workspace tree still defaults to `untitled.rs`; reuse the save panel's language picker
- Problems panel keeps a C file's diagnostics until that file is checked again; drop them when the buffer closes or the file is deleted
