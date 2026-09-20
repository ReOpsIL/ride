# Debug source paths (2026-09-20)

## The problem

lldb binds a breakpoint by matching the source path it is given against the file spec recorded in the debuggee's debug info, as a string. A file reached through a symlink has two spellings — the one the user opened (`/tmp/demo/src/shapes.cpp`) and its resolved form (`/private/tmp/demo/src/shapes.cpp`) — and only the spelling the compiler recorded binds. Which one that is depends on the build system:

| Build | Recorded spelling |
|---|---|
| CMake + clang | the path the build was invoked with, symlinks intact |
| Cargo + rustc | the resolved path |

macOS makes this the common case, not a corner: `/tmp` and `/var` are symlinks, so any workspace opened under them (every self-test copy, every scratch project) compiles under one spelling while the editor shows the other.

Sending one fixed spelling therefore cannot work. Ride used to canonicalize every breakpoint path: Rust debuggees bound, C and C++ debuggees under a symlinked root never did — the adapter answered `verified: false`, no location was ever bound, and the program ran to completion with no `stopped` event.

## The rule

`DebugSession::set_breakpoints` sends the path as the editor holds it. If the adapter binds nothing and the path has a distinct resolved twin, it sends the twin once and keeps whichever spelling bound. Two spellings exist, so at most two requests; there is no waiting and no polling.

The breakpoint store stays keyed by the editor's path. Paths the adapter reports back (breakpoint and stopped events) are matched to stored keys through their resolved forms (`source_path::same_file`), so a report in either spelling finds its breakpoint.

`src/debug/session/source_path.rs` owns the spelling policy; `store.rs` owns the store.
