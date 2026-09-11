# ride-demo

A small crate used by Ride's demo scenes and the `--demo selftest` scene. The self-test edits `src/main.rs` line by line, so keep its layout: `fn main() {` on line 8, `counter.record("ride");` on line 10, `counter.record("engine");` on line 11, and the closing brace on line 20.

Run it with `./scripts/run.sh samples/rust-demo` or check it in-process with `Ride --demo selftest --open samples/rust-demo --report /tmp/ride-selftest.txt`.
