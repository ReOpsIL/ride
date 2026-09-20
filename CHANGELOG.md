# Changelog

## 1.0.0 — 2026-09-20

First public release of Ride, a native macOS IDE for Rust, C and C++.

- **Editor.** Split panes with independent tabs and popups, workspace restore for tabs, caret, folds and layout, fold chevrons, bracket-pair highlight, Reformat Selection, Complete Statement, Replace in Project, nested snippet stops, and delete/rename from the project tree. Breakpoints, highlights, folds and underlines shift with edits; a whole-file replacement is one undo step.
- **C and C++.** Extension-less system headers open as C++ (read-only under the sysroot), a project-wide clang check with header-triggered recheck, and cheat sheets for CMake, Make and TOML alongside Rust and C.
- **Documentation.** Quick Documentation (⌃J / F1) renders the full doc block with intra-doc links; Quick Definition (⌥Space) peeks the source, one segment per declaration or implementation.
- **Build, run and test.** Cargo, CMake, Make and compilation-database projects; a Targets panel; Build, Run and Run Tests with saved configurations; a run console with clickable locations; Tests panel for cargo, GoogleTest, Catch2 and CTest; Run File and Recompile File; a terminal on SwiftTerm.
- **Debugger.** `lldb-dap` from Xcode: gutter breakpoints, step, frames, locals with the toolchain's Rust formatters, watches and a Debug panel.
- **Usages and rename.** A per-workspace reference index, Find Usages, and Rename locally or across the project with a preview that skips stale text.
- **Generate and refactor.** Generate C++ constructors, getters, setters and operators, and Rust `impl` / `new` / `Default` / `Display`. Extract Variable, Introduce Constant, Inline Variable and Safe Delete; each refuses when the selection is not a single clear node.
- **Diagnostics and intentions.** Live cargo/clippy and clang checks while typing, clang-tidy on save, compiler fix-its, and an intention menu for imports, unused-prefix, missing `match` arms and applicable refactorings.
- **Hierarchy.** Callers, callees and type hierarchy in a side panel; dimmed "N usages" above items.
- **Index.** Completions from the local crate catalog, including items reached through cross-crate glob re-exports.
- **Install.** Universal (arm64 + x86_64) builds, Sparkle updates from GitHub Releases, and a Homebrew cask: `brew tap ReOpsIL/ride` then `brew install --cask ride`.
