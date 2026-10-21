# Remote toolchain

The editor stays on the Mac. Build, test, run, and debug run on one SSH endpoint. A VM, a container, a pod, and local Docker are four ways to reach that endpoint. They are not four executors.

## The endpoint

`src/remote/` owns the endpoint. `Endpoint::vm`, `container`, `docker`, and `pod` all produce the same value: user, host, port, an optional identity file, an optional `ProxyCommand`, and a local root paired with a remote root.

Docker and pod presets point SSH at `127.0.0.1:22` and set `ProxyCommand` to `docker exec` or `kubectl exec` running `nc %h %p`. SSH expands `%h` and `%p` on the Mac, then `docker exec` or `kubectl exec` is what places `nc` inside the container or pod, aimed at the `sshd` on its loopback. The container or pod must already be running `sshd`, and it must have `nc`. Ride does not install either. A container preset is a VM whose SSH daemon is published, plus an optional proxy command for the cases where it is not.

The SSH line is always non-interactive: `BatchMode=yes`, `RequestTTY=no`, a connect timeout, and server-alive probes. An unknown host fails. Password prompts are not supported. The remote command is one argument after `--`, so a DAP byte stream is not a terminal and a tool argument is not an SSH option.

Stopping a run is killing that local `ssh` process. The remote command is started with `exec`, so the dropped channel is the tool's session.

## Paths

One prefix pair. A path under the local root maps to the same relative path under the remote root, and the other way around. The match is on path components, so `/work` is not a prefix of `/workspace`. A root of `/` is rejected.

`Endpoint::invocation` maps the working directory and any absolute argument under the local root. An absolute path already under the remote root is kept. Any other absolute path is rejected, so a Mac tool path such as `/usr/bin/cargo` is never sent across. A bare name (`cargo`, `cmake`, `lldb-dap`) is left bare and resolved by the remote `PATH`. Environment values are sent as given; this module does not rewrite them and does not forward the Mac `PATH`.

## Sync

Before a remote build, run, test, or debug, Ride packs the local root with `tar` and unpacks it over the same SSH command:

`tar -c -C <local root> --exclude target --exclude build --exclude .git .`

piped into

`ssh … "mkdir -p <remote root> && tar -x -C <remote root>"`

`rsync -e` is not used. Its remote-shell option splits on spaces, which breaks a `ProxyCommand` that contains `docker exec` or `kubectl exec`. Stopping the sync kills the local `tar` and the local `ssh`. A non-zero `tar` fails the run even when `ssh` exits 0.

## What the app does

When the workspace endpoint is enabled, Build, Run, Run Tests, Run File, and Recompile File sync and then spawn that SSH invocation. The run config's own environment is the remote environment. The Mac `PATH` stays on the Mac process that finds `ssh` and `tar`. The Run Output badge shows the SSH command, which includes the host.

Debug runs remote `lldb-dap` on that same channel. Breakpoints are stored under the Mac path and sent as remote paths. Stopped frames and breakpoint reports are mapped back before the editor sees them. A path that is not under the remote root, such as a system library, is left as the adapter spelled it. The Mac Rust sysroot is not sent, so remote `Vec` and `String` formatters are not loaded.

The endpoint is one value in the workspace state, edited from Run › Remote Toolchain…. VM, container, pod, and local Docker are reach presets. The live workspace path is the local root at the moment of the call.

## Test Remote

The sheet's Test Remote button checks the draft settings without saving them and without copying anything. `Endpoint::probe` refuses an identity file that does not exist on the Mac, then runs one SSH command whose `sh -c` script reports the login user and system, whether Remote Root exists and is writable or whether its nearest existing parent is writable, and the remote `PATH` location of each tool the project needs. The tools are `tar`, `cargo` when the local root has `Cargo.toml`, `cmake` when it has `CMakeLists.txt`, and `lldb-dap`. A missing `lldb-dap` is a warning; the others fail. With neither manifest, `cargo` and `cmake` are warnings.

`remote::read_probe` turns the output into checks. When no probe line came back, the SSH output is matched against known failures (stopped or unknown container, missing `nc`, unknown host key, rejected key, refused or timed-out connection) and the hint is shown above ssh's own last lines. The app kills the probe after 30 seconds. Identity accepts `~`, which the app expands before the engine sees it.

A single-file compile whose output path sits outside the mapped root is rejected. Remote `cargo check` and `clang -fsyntax-only` are not wired, so Problems still come from the local compiler. `docs/product/feature-inventory.md` still says remote targets are none until a run is seen leaving the Mac.
