# Tutorial: Rust

Open `samples/rust-demo` as the workspace (**File ▸ Open…** or the welcome screen). This crate is the one Ride's demo scenes and `--demo selftest` drive.

Keep the layout of `src/main.rs` if you run the self-test later: `fn main() {` on line 8, `counter.record("ride");` on line 10, `counter.record("engine");` on line 11, and the closing brace on line 20.

```
Cargo.toml
src/main.rs    Counter construction and two record calls
src/util.rs    Counter, record, counts_one
```

## Completions and the cheat sheet

Open `src/main.rs`. Type `Has` and trigger completion (`⌃Space` if it is not already up). Rows come from the buffer, this crate, and the catalog (including `std`). A selected row's documentation sits in the card on the right; an `use` tag means accepting will add the import.

The cheat sheet stacks under the list when **Cheat sheet with completions** is on. `⌃⇧Space` pins it on its own. Arrow keys or a click select a row; `↩` or `⇥` inserts it as a snippet with tab stops.

## Navigation

In `src/main.rs`, hover `Counter` for its signature and first doc paragraph. `F12` jumps to the definition in `src/util.rs`. `⌃J` opens Quick Documentation for the whole doc block. `⌥Space` peeks the definition without leaving the file.

`⇧⌥⌘O` searches symbols in the workspace and the crate catalog. `⌘P` opens files by path.

## Check, run, test, debug

Save to run `cargo check`. Diagnostics appear in Problems (`⌘6`) and as underlines. `⌘B` builds the selected target, `⌘R` runs it, `⇧⌘R` runs tests. A ▶ in the gutter next to `#[test]` runs that test alone.

Click the line number on `counter.record("ride");` to set a breakpoint, then debug (`⌃⌘R`). The Debug panel lists the frame, locals (with the toolchain's Rust formatters), and watches. Debugging needs developer mode: `sudo DevToolsSecurity -enable`, once.
