# Attach to a running process (2026-10-21)

## Why

Ride's debugger used to launch the debuggee itself, so only that process was ever debugged. After `fork()` the child ran free, and a program started some other way (a terminal, a script, a service) could not be debugged at all. lldb on macOS cannot follow a forked child: there is no `follow-fork-mode`, and lldb-dap has no setting for it. Attaching is the way in: by PID once the process exists, or by waiting for the next process with a given name.

## What the user sees

**Debug › Attach to Process…** opens a sheet with two modes:

| Mode | What it does |
|---|---|
| Running Process | Lists the user's own processes (name, PID, parent PID), newest first. Ride itself is left out. A filter matches a name substring or a PID prefix. Refresh lists them again. |
| Wait for Launch | Takes a program name or path, defaulting to the selected run target's binary. Ride attaches to the next process with that name and skips the ones already running. |

The menu item is enabled whenever no debug session is active. It does not need a run target.

Once attached, it is the same session as a launch: breakpoints, the stopped line, threads, frames, locals, watches, Evaluate and hover all behave the same. Breakpoints set before attaching are sent during the handshake.

**Stop** (⌘F2) detaches and leaves the process running. A launched process is still terminated on Stop.

While Ride waits for a process, the session is in the launching state and lldb-dap prints `Waiting to attach to "<name>"...` to the Run panel. Stop cancels the wait.

## Forked children

A child created by `fork()` without `exec` has its parent's name and binary. Two ways to reach it:

- **By PID.** Start the program with Run (not Debug), read the child's PID (the Parent column in the picker helps), and pick it.
- **By waiting.** Start the parent first, then attach with Wait for Launch on the program name before the parent forks. lldb's wait skips processes that already exist, so it catches the child, not the parent. If the wait starts before the parent, it catches the parent instead.

Start the parent with Run, not Debug. Under Debug, lldb debugs only the parent and the child runs straight through its breakpoints. Ride also runs one debug session at a time, so it cannot debug the parent and attach to the child together.

The debugger lab has a `fork` scenario for trying this (`samples/debugger/README.md`, section 10).

## Engine

| Piece | Where |
|---|---|
| FFI records: `DebugAttach { process, cwd, exception_filters }`, `AttachProcess::Pid { pid, program }` and `AttachProcess::WaitFor { program }`, `DebugProcess` | `src/ffi/debug_attach.rs` |
| `Engine::debug_attach`, `Engine::debug_processes` beside `debug_launch` | `src/engine/debug.rs` |
| `DebugTarget::{Launch, Attach}`: the request command, the Rust-target hints, the exception filters, ownership of the debuggee, the handshake timeout | `src/debug/target.rs` |
| Maps a target to DAP `launch` or `attach` arguments | `src/debug/session/start_request.rs` |
| `AttachArguments { pid, program, waitFor, initCommands }` | `src/debug/protocol/attach.rs` |
| Process listing: `ps -x -o pid=,ppid=,comm=`, parsed and sorted newest first | `src/debug/processes.rs` |

The handshake is the same for both requests: `initialize`, then `launch` or `attach`, then wait for `initialized`, send breakpoints and exception filters, send `configurationDone`, then wait for the start response. Two lldb-dap behaviours shape it:

- Xcode's lldb-dap answers `attach` only after the process is attached, and sends `initialized` after that. Upstream lldb-dap 21 sends `initialized` first and answers after `configurationDone`. With `waitFor`, either wait lasts as long as the user takes to start the program, so a wait-for target allows 24 hours for both instead of the usual 30 seconds. Stop is how the user ends it.
- An attach by PID sends only `pid`. The program path is not sent to lldb. It is used, together with `cwd`, only to decide whether the target is Rust (which loads the toolchain's lldb formatters through `initCommands`).

### Disconnect

`disconnect` sends `terminateDebuggee: true` for a launch and `false` for an attach (`DebugTarget::owns_debuggee`).

It is sent only once the adapter has reported a debuggee with the DAP `process` event (`session/debuggee.rs`). Before that there is nothing to detach from. An lldb-dap waiting for a process is blocked inside the attach request and would not answer `disconnect` anyway. So Stop then kills the adapter at once instead of waiting 3 seconds for a reply that never comes. This rule covers launches too: lldb-dap sends `process` as soon as the launched process exists.

## Tests

| Test | What it proves |
|---|---|
| `tests/debug_attach.rs` (fake adapter) | attach by PID sends only `pid`; wait-for sends `program` and `waitFor: true`; Stop detaches an attached process and terminates a launched one; Stop while waiting ends the session once, with no failure; process listing parse |
| `tests/debug_attach_live.rs` (lldb-dap, developer mode) | the lab's `fork` scenario: attach to the child by PID, and by waiting for the program name; both stop at the breakpoint in `child_work`, and the child is still alive after Stop |
| `tests/debug_protocol.rs::attach_by_pid_and_by_waiting_round_trip` | the two `attach` argument shapes round-trip |
| `RideTests/AttachModelTests` | filter, selection, the choice built for each mode |
| Self-test "menu debug attach" (rust demo) | the menu item opens the sheet with a process list that leaves out Ride |
| Self-test "lab attach pid", "lab attach wait" and their stop steps (debugger lab, dev) | the same as the live test, driven through Run, the menu and the sheet's model, in Rust, C++ and C |

## Not covered

- Attaching to processes of other users or to hardened-runtime binaries: macOS refuses, and lldb-dap's error goes to the Run panel.
- Remote targets, core files and following `exec` are out of scope.
