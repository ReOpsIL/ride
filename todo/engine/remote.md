# Remote toolchain

Build, run, test, and debug call the SSH endpoint when the workspace sheet has one enabled. Sync is `tar` over that SSH command, not `rsync`. `docs/product/feature-inventory.md` still says remote targets are none until a run is seen leaving the Mac.

- Remote `cargo check` and `clang -fsyntax-only`. Problems still come from the local compiler. Console links are not rewritten when the compiler prints a remote path.
- Remote Rust `Vec` and `String` formatters. The debug session sends no Mac sysroot, so those init commands are not loaded.
- A single-file compile writes its output outside the mapped root, and `invocation` rejects that absolute path.
- IPv6 hosts. The host check rejects `::1` on purpose.
