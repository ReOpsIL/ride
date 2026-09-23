# Getting started

Ride is a native macOS IDE for Rust, with C and C++ editing. This page covers install, opening a project, and the loop you use every day.

## Install

Download the latest build from [GitHub Releases](https://github.com/ReOpsIL/ride/releases/latest), unzip it, and move `Ride.app` to `/Applications`.

Or install with Homebrew:

```sh
brew tap ReOpsIL/ride && brew install --cask ride
```

To build from this repository:

```sh
./scripts/install.sh            # Release Ride.app → /Applications
./scripts/install.sh ~/Applications
```

Requirements:

- macOS with Xcode (the debugger, `clang`, and `clang-format` come from the toolchain)
- a Rust toolchain via [rustup](https://rustup.rs); Ride adds the `rust-src` component if it is missing so `std` is indexed

First launch indexes your Cargo registry and the Rust sysroot (about a minute). Progress sits in the status bar. Later launches are incremental. The index lives at `~/Library/Application Support/Ride/index`.

Debugging needs macOS developer mode, once: `sudo DevToolsSecurity -enable`.

## Open a project

Launch Ride and choose **Open Folder…** on the welcome screen, or **File ▸ Open…** (`⌘O`). Point it at a folder that contains `Cargo.toml`, `CMakeLists.txt`, a `Makefile`, or `compile_commands.json`. Recents appear on the welcome screen.

Ride treats that folder as the workspace: the project tree on the left, targets below it, the editor in the middle, and the file outline on the right.

Three samples in this repository are meant to be opened that way:

- `samples/rust-demo` — a small crate; see [the Rust tutorial](tutorial-rust.md)
- `samples/c-demo` — C with headers and a compile database; see [the C tutorial](tutorial-c.md)
- `samples/cpp-demo` — C++20 with classes and `std::`; see [the C++ tutorial](tutorial-cpp.md)

## The daily loop

1. **Open a file.** `⌘P` jumps to a path; `⌘E` reopens a recent file. Click in the tree, or use Go to Symbol in File (`⌥⌘O`) / Project (`⇧⌥⌘O`).
2. **Edit.** Completions come from the buffer, the workspace, and every crate already on disk, including the rustc sysroot. Rows show the signature and origin crate; the card on the right is the selected item's docs. The cheat sheet (`⌃⇧Space`, or automatically under completions) inserts language templates as snippets. Hover for a signature; `⌃J` / `F1` opens Quick Documentation; `⌥Space` peeks the definition; `F12` jumps to it.
3. **Check.** Save runs `cargo check` (Rust) or `clang -fsyntax-only` (C/C++, flags from `compile_commands.json`). Diagnostics land in the Problems panel (`⌘6`) and as underlines. `⌥⌘B` checks the current file; `⇧⌥⌘B` checks the project. `F2` / `⇧F2` walk problems. Reformat Document is `⌃⇧I`.
4. **Build, run, test.** The sidebar lists targets from `cargo metadata`, the CMake File API, a Makefile, or `compile_commands.json`. `⌘B` builds the selected target, `⌘R` runs it, `⇧⌘R` runs its tests. Output goes to the Run panel (`⌘4`) with clickable `path:line:col` links. A ▶ in the gutter runs one test; the Tests panel groups results per suite. `⌥F12` opens a terminal in the workspace root.
5. **Debug.** Click a line number to set a breakpoint (View → Line Numbers hides the numbers; the narrow column left of the code still takes breakpoints), then `⌃⌘R`. F7 / F8 / `⇧F8` step; `⌘F2` stops. The Debug panel (`⌘3`) shows frames, locals, watches, and Evaluate Expression (`⌥F8`). Hover an identifier while stopped to see its value.

`⌘?` lists every shortcut. The generated table is [Keyboard shortcuts](shortcuts.md).
