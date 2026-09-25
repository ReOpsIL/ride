# Tool lookup and the child PATH

A macOS app launched from Finder, the Dock or Xcode inherits launchd's environment, whose `PATH` is `/usr/bin:/bin:/usr/sbin:/sbin`. Nothing the user's shell adds (`~/.cargo/bin`, `/opt/homebrew/bin`, Go, pyenv) is on it, so a Run configuration whose argv starts with `cargo` failed with `command not found: cargo` even though the terminal had it.

## Resolution

`app/Ride/Tools/ShellPath.swift` resolves the PATH once per process and caches it:

1. run the user's login shell (`$SHELL`, default `/bin/zsh`) as `-lc 'printf %s "$PATH"'`; the last output line containing `/` is the login PATH (rc files that echo a banner are skipped),
2. append the app's inherited `PATH`,
3. append the fallback list (`/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, `/bin`, `/usr/sbin`, `/sbin`, `~/.cargo/bin`),

dropping empty entries and duplicates while keeping the first position. `merged(login:inherited:fallback:)` is the pure part and has `ShellPathTests`. `RideApp.init` calls `ShellPath.prime()` so the shell probe runs on a background queue at launch instead of on the first Run.

## Consumers

- `app/Ride/Run/ProcessLookup.swift` finds a bare tool name (`cargo`, `clang-tidy`) in `ShellPath.directories`; names with a `/` resolve against the working directory or as given.
- `ProcessRunner` sets the child's `PATH` to the resolved value before merging the configuration's own env, so cargo's build scripts, `cc` and rustup proxies see the same PATH the user's terminal has.
- `AnthropicLogin` gives the `ant` CLI the same PATH.

Anything else that spawns a tool by bare name goes through `ProcessLookup`; do not add per-call hardcoded directory lists.
