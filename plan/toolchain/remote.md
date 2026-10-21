# Remote toolchain

Edit on the Mac. Build, test, run, and debug on a VM, a container, a pod, or local Docker. One SSH endpoint does all four. `plan/roadmap/next-1.3.md` listed remote debugging as not planned; this plan is the decision to do it.

The rule the code follows is `docs/product/remote-toolchain.md`. The open slices are `todo/engine/remote.md`.

## Decisions

- The editor, the index, and completion stay local. The files on the Mac are the source of truth.
- Every remote action is one `ssh` process. VM, container, pod, and local Docker only change how that process is addressed. Docker and pod presets use `ProxyCommand` to reach an `sshd` that is already running inside. Ride does not grow a `docker exec` or `kubectl exec` runner beside SSH.
- The remote command has no tty. Debug will be the current DAP client with `lldb-dap` on the far side of the same SSH channel.
- Paths cross the boundary only through the local-root / remote-root prefix map.
- Tool names stay bare. The Mac `PATH` is not forwarded. Absolute Mac paths are mapped or rejected.
- Unknown hosts fail closed. There is no password prompt and no `StrictHostKeyChecking=no`.
- One endpoint per workspace.

## Slices

1. **Endpoint, path map, SSH argv.** `src/remote/`, `tests/remote.rs`. Done.
2. **Run, build, and test.** When the workspace endpoint is enabled, the run output syncs, then spawns `invocation` instead of the local argv. The run config's own env is passed through. `ShellPath` stays on the Mac. Stop kills the local `ssh`. UniFFI records are `RemoteLink` and `RemoteCommand`. The Cargo, CMake, and Make planners do not learn a second argv shape. Done.
3. **Sync.** Before that process starts, `tar` packs the local root and the SSH command unpacks it into the remote root. `target/`, `build/`, and `.git/` stay behind. `rsync -e` is not used because it splits on spaces and would break `ProxyCommand`. A remote root of `/` is already unrepresentable. Done.
4. **Debug.** `debug_launch_remote` spawns `lldb-dap` through `invocation`. `debug_launch` is unchanged. `setBreakpoints` sends remote paths. Stopped frames and breakpoint events come back through `to_local` before the editor sees them. The adapter's `program` and `cwd` are remote paths. No debugserver port forward. The Mac sysroot is not sent. Done.
5. **Workspace UI.** One endpoint in the workspace state. Run › Remote Toolchain… edits reach, user, host, port, identity, and the remote root. Docker and pod fields edit the container, namespace, and pod, and the preset fills the proxy. The run badge shows the SSH command, including the host. Done.
6. **Remote diagnostics.** `cargo check` and `clang -fsyntax-only` go through the same invocation so Problems match the remote compiler. The local oracle stays until this is boring. Not done.

## Out of this plan

SFTP as the editor's filesystem, more than one endpoint, a remote rust-analyzer or clangd, GUI programs, IPv6 hosts, and a transport that is not SSH.
