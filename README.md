# Ride

Native macOS IDE for Rust, with C and C++ editing. A SwiftUI/AppKit shell (`app/`) over a Rust language engine (`src/`) that discovers crates on disk, extracts items with tree-sitter, indexes them with Tantivy, and answers completion, highlight and outline queries in-process through UniFFI. C and C++ buffers get tree-sitter highlighting, outline, parse errors, keyword and buffer-local completion, in-file definitions and clang-format.

![Ride editing a Rust file with the completion popup, documentation card and outline](docs/images/ride-editor.png)

Completions come from the open buffer, the workspace and every crate already on disk, including the rustc sysroot, in under a millisecond. Markdown files get tree-sitter highlighting, a heading outline and a rendered preview.

![Ride showing a markdown file next to its rendered preview](docs/images/ride-markdown.png)

## Install

```sh
./scripts/install.sh            # builds a Release Ride.app and installs it to /Applications
./scripts/install.sh ~/Applications
```

Requires Xcode and a Rust toolchain (rustup); the script adds the `rust-src` component if it is missing.

## Build and run

```sh
cargo test                       # engine tests
cargo clippy --all-targets -- -D warnings
./scripts/build-engine.sh        # xcframework + Swift bindings + ride-engine CLI
./scripts/run.sh [folder]        # build Ride.app and open a folder
```

Two sample projects exercise the C and C++ support end to end (member completion through headers, go to definition into `include/`, `compile_commands.json`-driven diagnostics, clang-format): `./scripts/run.sh samples/c-demo` or `samples/cpp-demo`, each with a README checklist.

The one-shot indexer writes to `~/Library/Application Support/Ride/index/`:

```sh
target/debug/ride-engine index --project-path . --index-dir <dir> [--force]
target/debug/ride-engine query HashMap --index-dir <dir>
target/debug/ride-engine status --index-dir <dir>
```

## Where things live

- `docs/README.md` — documentation index
- `plan/ride_draft.md` — product and architecture spec (authoritative)
- `plan/roadmap/improve-extend.md` — current roadmap
- `todo/` — open follow-ups per module
- `AGENTS.md` — engineering rules for this repo
