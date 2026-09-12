# Feature inventory — running and debugging (2026-09-12)

What Ride can do today for building, running, testing and debugging native code, per language, with the verification status of each item. Status values: **live** (exercised against the real toolchain or adapter by a test or the `--demo selftest` scene), **built** (implemented, covered by unit or fake-adapter tests, not yet exercised end to end on that language), **none** (not implemented). Plan references point at `plan/roadmap/next-impl.md`.

| Field | Value |
|---|---|
| Branch | `grok/next-impl` at the end of release 1.2 |
| Languages | Rust, C, C++; assembly has no support of any kind |
| Debugger | `lldb-dap` from Xcode over the Debug Adapter Protocol, engine-side client in `src/debug/` |
| Prerequisites | Xcode with the Metal toolchain, a rustup toolchain, macOS developer mode for debugging (`sudo DevToolsSecurity -enable`) |

## 1. Project model and build

| Capability | Rust | C / C++ | Status | Where |
|---|---|---|---|---|
| Target discovery | `cargo metadata`: bin, lib, test, bench, example per package | CMake File API (configures `build/<profile>` with `CMAKE_EXPORT_COMPILE_COMMANDS`), Makefile rule targets with `make -n` sources, or every source of a bare `compile_commands.json` | live on `samples/rust-demo`, `samples/cpp-demo` | `src/project/`, P1–P5 |
| Detection order | Cargo → CMake → Make → compile database; a CMake project without `cmake` on PATH falls through and reports a notice | | live | `src/project/mod.rs` |
| Profiles | debug, release | Debug, Release, RelWithDebInfo for CMake (picker is selection state only; detection runs the default profile) | built | P4, P5 |
| Build command | `cargo build -p <pkg> --bin <name>` with `--message-format=json-diagnostic-rendered-ansi` | `cmake --build build/<profile> --target <name>` or `make <target>` | live (Rust), built (C++) | Q3, Q4b |
| Build diagnostics into Problems | rendered cargo messages | clang text output parsed with the build's base directory | live (Rust), built (C++) | `src/engine/build_output.rs`, Q4b |
| Whole-project C check | | `clang -fsyntax-only` over the compile database on ⇧⌥⌘B; a header save rechecks its includers | live | 1.1-6b |
| Reload on manifest change | `Cargo.toml`, `Cargo.lock` | `CMakeLists.txt`, `Makefile`, `compile_commands.json` at the root or `build/` | built | `ManifestWatch.swift` |

## 2. Run

| Capability | Status | Notes |
|---|---|---|
| Run the selected target (⌘R) | live (Rust), built (C++) | argv from the model's `run`; disabled for libraries |
| Run configurations per target | built | arguments, environment, working directory, `RUST_BACKTRACE`, sanitizers; saved in the workspace state; edited in a sheet |
| Sanitizers | built, unverified live | Cargo: `RUSTFLAGS=-Zsanitizer=…` plus `--target <host>` (nightly only, flagged); CMake: `-DCMAKE_CXX_FLAGS=-fsanitize=…` at configure time; Make and compile-database projects get none |
| Run output panel | live | ANSI SGR colours, `path:line:col` links restricted to source extensions, 5000-line ring, Stop (SIGTERM then SIGKILL), Rerun, "Stop and rerun?" on a second run |
| Stop semantics | live | every line and finish carries a run id; a stopped or replaced run cannot publish diagnostics or test results into the next one |
| Single-file run (⌃⇧R) | live (C++ on `samples/cpp-demo`), built (C, Rust) | `clang`, `clang++ -std=c++20`, `rustc --edition 2021` into the support directory; include and define flags come from the compile database when the file has an entry |
| Recompile File (⇧⌘F9) | live (C++) | runs the compile database entry's exact argv in its directory |
| Terminal (⌥F12) | live | SwiftTerm, login shell in the workspace root, tabs, Open in Terminal from the tree |

## 3. Test

| Capability | Rust | C / C++ | Status |
|---|---|---|---|
| Frameworks | `cargo test` human output, `cargo test -- --list` | GoogleTest (`--gtest_list_tests`, `[ RUN ]`/`[ OK ]` lines), Catch2 (`--reporter xml`, also for `--list-tests`, with locations and durations), CTest (`--show-only=json-v1`, `--output-on-failure`) | live (cargo), built with real captured fixtures (GoogleTest hand-written from the documented format, Catch2 and CTest captured from real runs) |
| Gutter run markers | `#[test]` and `fn main`, module-qualified, block comments ignored | `TEST(`, `TEST_F(`, `TEST_P(`, `TEST_CASE(` at column 0 (block comments not yet ignored, see `todo/engine/remaining.md`) | live (Rust), built (C++) |
| Tests panel (⌘5) | pass/fail tree per suite, output per test, filter, Rerun Failed with the right filter per framework (`mod::leaf`, `Suite.Leaf`, `-R a|b`) | same | live (Rust), built (C++) |
| Run Tests (⇧⌘R) | `cargo test -p <pkg>` | `ctest --test-dir build/<profile>` or `make test` when the rule exists; a GoogleTest or Catch2 binary needs a marker click or a Test-kind target | live (Rust), built (C++) |

## 4. Debug

Engine: `src/debug/` (transport with framing and a `RIDE_DAP_TRACE=<file>` frame log, protocol types round-tripped against captured `lldb-dap` frames, a session state machine with compare-and-set transitions, a registry that retires sessions on termination). App: `app/Ride/Debug/`.

| Capability | Status | Notes |
|---|---|---|
| Launch the selected target (⌃⌘R) | live (Rust) | builds first, then launches `target/<profile>/<bin>` for Cargo or argv[0] for other kinds, with the run configuration's arguments, environment and cwd |
| Attach to a process | none in the app | the protocol types carry `attach` (pid, core file) and the D2 fixtures were captured through a core-file attach; no menu, no engine entry point |
| Line breakpoints | live | click the line number or ⌘F8; paths canonicalised before `setBreakpoints` (R32) so symlinked directories verify; red marker filled when verified, hollow when not |
| Conditional and hit-count breakpoints | built | right-click the marker; sent as `condition` and `hitCondition`; re-sent for that file while the process runs |
| Breakpoints persist per workspace | live | in the workspace state, keyed by absolute path |
| Exception breakpoints | built | the filters the adapter advertises (`cpp_throw`, `cpp_catch` on Xcode 26's adapter), toggled in the Debug menu, enabled ones sent on launch |
| Rust panic breakpoint | built | Xcode's adapter has no `rust_panic` filter; a function breakpoint on `rust_panic` is set for Rust targets |
| Continue, Step Over (F8), Step Into (F7), Step Out (⇧F8), Pause, Stop (⌘F2) | live (stop, step over on Rust), built (others) | Stop disconnects with a 3 s timeout, then kills the adapter |
| Stopped line highlight and editor jump | live | follows the top frame's file, opening it if needed |
| Threads and frames | live | Debug panel (⌘3), click a frame to select it and jump |
| Locals, scopes, variables tree | live (Rust) | lazy children by `variablesReference`, paging over 100, loads off the main thread with a stop generation so stale results are dropped |
| Rust value summaries | live | `Vec`, `Option`, `String`, `HashMap` through the toolchain's `lldb_lookup.py` and `lldb_commands`, imported by launch `initCommands` from the engine's resolved sysroot |
| C++ value summaries | built, unverified live | lldb's built-in libc++ formatters; no C++ live debug test or self-test step yet |
| Watches | live | evaluated with context `watch` on every stop, persisted per workspace |
| Evaluate Expression (⌥F8) | built | `repl` context |
| Hover value while stopped | built | `hover` context, off the main thread, nothing shown if the process resumed |
| Registers | built | shown as a scope when the adapter reports one; no register editing |
| Memory view, heap or allocation inspector | none | |
| Disassembly, instruction stepping | none | `SteppingGranularity` exists in the protocol types only |
| Data breakpoints, watchpoints | none | |
| Reverse debugging, record and replay | none | |
| Multi-process, fork follow, remote targets | none | |
| Core files, crash logs | none in the app | |

## 5. Assembly

Nothing: no `.s`/`.S` highlighting or outline, no disassembly view, no instruction-level stepping, no register editing. The tree-sitter grammar set is Rust, C, C++, TOML, Make, CMake and Markdown.

## 6. Verification map

| Check | What it proves | How to run |
|---|---|---|
| `cargo test --test debug_session` | session state machine, breakpoint editing, disconnect and failure paths against the scripted fake adapter, plus one live launch of `samples/rust-demo` stopping on line 10 | needs developer mode for the live case |
| `cargo test --test debug_render_live` | a live Rust launch shows `size=3` for a `Vec<u32>` and the `Option<String>` value | needs developer mode |
| `--demo selftest` on a copy of `samples/rust-demo` | Build, Run, Run Tests, gutter marker, build diagnostics, stop-and-rerun, breakpoint toggle and persistence, Debug stop on line 10, Step Over to 11, Stop, Debug panel, watches, variable paging (91 steps) | `Ride --demo selftest --open <copy> --report <file>` |
| `--demo selftest` on a copy of `samples/cpp-demo` | header/source switch, Complete Statement, fold, Quick Definition, Run File link error, Recompile File (32 steps); no C++ debug steps yet | same with `--file src/shapes.cpp` |

## 7. Gaps worth the next cards

1. C++ live debugging: a self-test on `samples/cpp-demo` that stops in `Circle::area`, expands a `std::vector` local and steps; confirms the libc++ formatters and the `cpp_throw` filter.
2. Attach to process: a menu item with a process picker, `attach` through the existing protocol types and the same session.
3. Assembly: a tree-sitter grammar for GNU and NASM syntax for highlighting and outline; a disassembly view fed by `lldb-dap`'s `disassemble` request with instruction stepping.
4. Memory view: `readMemory` request into a hex pane with a pointer follow.
5. Watchpoints: `dataBreakpointInfo` and `setDataBreakpoints` on a variable's context menu.
6. C++ `TEST(` markers inside block comments (`todo/engine/remaining.md`).
