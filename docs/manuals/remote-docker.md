# Local Docker remote

A Rust container on local Docker that Ride's remote toolchain can reach over SSH.

## Start

```bash
scripts/remote-docker/up.sh
```

The script builds `ride-rust-remote` (Debian trixie, stable Rust, `lldb-dap` 19, `gdb`, `sshd`, `nc`). It creates `~/.ssh/ride_docker` if missing and runs container `ride-rust`. It publishes SSH on `127.0.0.1:2222` and adds the container host key to `~/.ssh/known_hosts` for `127.0.0.1` and `[127.0.0.1]:2222`. Running it again rebuilds and replaces the container. Volumes keep the host key, `/work`, and the cargo registry.

Overrides: `RIDE_REMOTE_NAME`, `RIDE_REMOTE_PORT`, `RIDE_REMOTE_KEY`.

## Connect

```bash
ssh -i ~/.ssh/ride_docker -p 2222 dev@127.0.0.1
```

In Run › Remote Toolchain…, use one of these:

- Docker preset: container `ride-rust`, user `dev`, identity `~/.ssh/ride_docker`, remote root `/work/<project>`.
- VM or container preset: host `127.0.0.1`, port `2222`, same user, identity, and root.
- Press Test Remote before saving. Every row should be green.

## Container facts

- User `dev` owns `/work`, `CARGO_HOME`, and `RUSTUP_HOME`, so `cargo install` and `rustup component add` work without root.
- `/etc/environment` carries the cargo `PATH` into non-interactive SSH commands.
- Key auth only. Root login and passwords are off.
- `SYS_PTRACE` and `seccomp=unconfined` let `lldb` and `gdb` attach and turn off ASLR.
- The container is `linux/arm64` on Apple silicon. Binaries built in it do not run on the Mac.
