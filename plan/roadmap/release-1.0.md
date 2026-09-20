# Ride — Release 1.0 public cards (2026-09-20)

Release 3.2 of `plan/roadmap/level-up.md`. Executor contract: `plan/roadmap/next-impl.md` sections 0–1 apply. Executors are Grok (Tier A, `scripts/run-cards.sh` with `CARDS_FILE=plan/roadmap/release-1.0.md`) or Opus subagents (Tier B) in worktrees branched from `main`; Sonnet reviews; the reviewer re-runs gates and merges with `--no-ff`. Self-test runs never overlap on one machine: check `ps -eo etime,command | grep MacOS/Ride | grep -v grep` before launching one and wait until it is empty.

State on 2026-09-20 (facts, not assumptions): no git tag, no `CHANGELOG.md`, `MARKETING_VERSION` 0.1.0 and `Cargo.toml` 0.1.0; `scripts/release.sh` archives a universal build, signs, zips, optionally notarizes and generates a Sparkle appcast, writes to `target/release-app/`, uploads nothing; `.github/workflows/engine.yml` runs on every push (fmt, clippy, test, xcframework lipo check, app build+test, both self-tests) with no tag trigger and no artifacts; `Info.plist` has `SUFeedURL` pointing at the GitHub latest release `appcast.xml` and a placeholder `SUPublicEDKey`, and the Check for Updates item is hidden while the key is the placeholder; `WelcomeView` has Open Folder, recents, a `rust-src` hint and six shortcut hints; the Tools installer (`src/discover/tools.rs`, `app/Ride/Tools/`) knows rustfmt, clippy, clang, clang-format, taplo, cmake-format and git but not rustup, rust-src, cmake or the Command Line Tools; `DeveloperMode.isEnabled` exists and is not surfaced; there is no crash or panic reporting (engine panics are absorbed by `catch_unwind` with no hook); nothing handles `ride <path>`, `application(_:open:)`, document types or a URL scheme; fold chevrons, bracket-pair highlight, Reformat Selection and tree ⌫/↩ are done, CRLF→LF and the tree's New File picker are open; `docs/manuals` and `docs/site` do not exist; the ⌘? list is a hand-kept array in `app/Ride/Design/ShortcutsView.swift`; latency is measured by `ride-engine complete --repeat` but not gated, `tests/query.rs` asserts a 20 ms mean only; no file-length check; 7 non-generated files exceed 220 lines.

| Batch | Cards | Notes |
|---|---|---|
| A | P-1, P-7, P-8a | scripts, CI, docs, engine tests: no app source beyond the version bump |
| B | P-3, P-4, P-6 | app cards with disjoint files |
| C | P-2, P-5, P-8b | onboarding, live C/C++ verification, the file splits (runs alone, it touches the busiest files) |

## P-1 Release train — Tier A

- Version 1.0.0 in `Cargo.toml` and both `MARKETING_VERSION` settings; `CURRENT_PROJECT_VERSION` 100. `scripts/release.sh` keeps reading the version from `Cargo.toml`; add a check that the two agree and fail otherwise.
- `CHANGELOG.md` at the repo root (allowed: it is a release entrypoint) with a `## 1.0.0 — 2026-09-…` section listing what shipped since 0.1.0 in user terms, one bullet per feature area, derived from the "Landed" tables in `plan/roadmap/next-impl.md` section 7, `plan/roadmap/next-1.3.md` and `plan/roadmap/close-out-1.3.md`. No card ids in the changelog.
- `scripts/release.sh` also exports the dSYM (`xcodebuild -exportArchive` is not needed: copy `$ARCHIVE/dSYMs/Ride.app.dSYM` zipped next to the app zip) and writes `target/release-app/RELEASE.md` with the sha256 lines.
- `.github/workflows/release.yml`: on `push: tags: ['v*']`, macOS runner, imports the signing certificate from secrets when present (`RIDE_SIGN_P12_BASE64`, `RIDE_SIGN_P12_PASSWORD` into a temporary keychain, identity name in `RIDE_SIGN_IDENTITY`), sets `RIDE_SPARKLE_PUBLIC_KEY`/`RIDE_SPARKLE_PRIVATE_KEY_FILE` from `RIDE_SPARKLE_PUBLIC_KEY`/`RIDE_SPARKLE_PRIVATE_KEY` secrets and `RIDE_NOTARY_PROFILE` from `RIDE_NOTARY_KEY_ID`/`RIDE_NOTARY_ISSUER`/`RIDE_NOTARY_KEY_BASE64` (`xcrun notarytool store-credentials`), runs `scripts/release.sh`, then `gh release create "$TAG" --title "Ride $VERSION" --notes-file <the changelog section for that version> target/release-app/Ride-*.zip target/release-app/*.sha256 target/release-app/Ride-*.dSYM.zip target/release-app/appcast.xml`. Every secret is optional: without them the job produces an ad-hoc-signed zip and no appcast, and says so in the step summary. The `SUFeedURL` already points at `releases/latest/download/appcast.xml`, so publishing the appcast as a release asset completes the Sparkle loop.
- Homebrew cask: `packaging/homebrew/ride.rb` (`cask "ride"` with `version`, `sha256`, `url "https://github.com/ReOpsIL/ride/releases/download/v#{version}/Ride-#{version}.zip"`, `app "Ride.app"`, `zap trash` for `~/Library/Application Support/Ride`) plus a `scripts/cask-bump.sh` that rewrites version and sha256 from `target/release-app/`. The tap repository itself is outside this repo; document the `brew tap ReOpsIL/ride` step in `CHANGELOG.md`'s install note and in the README install section (README edit is allowed for this card only).
- Tests: `scripts/release.sh --dry-run` (new flag) validates the version agreement, prints the steps and exits 0 without building; a `tests/version.rs` asserts `Cargo.toml` and the pbxproj `MARKETING_VERSION` agree. Gates: `cargo fmt`, `cargo clippy`, `cargo test`, `bash scripts/release.sh --dry-run`, `actionlint` if installed (`brew install actionlint`; otherwise say so).

## P-2 Onboarding — Tier B

- Engine `src/discover/tools.rs` gains checks with install hints for: Command Line Tools (`xcode-select -p` succeeds), rustup (`rustup` on PATH or `~/.cargo/bin/rustup`), rust-src (existing `rust_src_available` reused), cmake. `tool_status()` returns them with the same `ToolRow` shape; the app's Tools installer lists them (install commands: `xcode-select --install`, the rustup curl one-liner shown but not run automatically, `rustup component add rust-src`, `brew install cmake`).
- `WelcomeView` gains a "Set up" section: one row per check with a green check or an Install button that opens the Tools sheet with that tool selected; a Debugging row showing developer mode state from `DeveloperMode.isEnabled` with the `sudo DevToolsSecurity -enable` command and a Copy button (never run sudo from the app); the section collapses when everything is green.
- "Try a sample project": the three `samples/*` folders are bundled as app resources (copy phase excluding `target/` and `build/`), and a button copies the chosen sample to a folder picked in a save panel, then opens it as the workspace with its main file, reusing `AppState+NewProject.createProject`'s open path.
- Self-test: a Rust step (END of the array) that calls the sample-copy function into a temp folder and asserts `Cargo.toml` and `src/main.rs` exist there and that the workspace root switched, then switches back. RideTests: a pure `SetupRows` model mapping tool rows to welcome rows with tests.
- Gates: engine gates, `scripts/build-engine.sh`, xcodebuild build test, Rust self-test alone (no other Ride running) `EXIT 0`.

## P-3 Crash and panic reports — Tier B

- Engine: `src/report/` with `install_panic_hook(dir)` called from `engine_start`: `std::panic::set_hook` appends one JSON line per panic to `<support>/reports/panics.jsonl` with time, message, location and `std::backtrace::Backtrace::force_capture()` text, then the previous hook runs. `EngineConfig` gains `report_dir: Option<String>`; the app passes `<Application Support>/Ride/reports`.
- App: `CrashReporter` installs `NSSetUncaughtExceptionHandler` (writes name, reason, `callStackSymbols`) and `signal` handlers for SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGABRT that write a pre-allocated report path with `backtrace(3)` symbols through async-signal-safe calls only (`write(2)`), to `<support>/reports/crash-<unix time>.txt`, then re-raise. On launch, if any report newer than the last acknowledged time exists, the notice bar shows "Ride crashed last time" with Copy Report (all new reports concatenated to the pasteboard) and Dismiss; a preference stores the acknowledged time. Keep at most 20 reports. No network.
- Tests: `tests/report.rs` triggers a panic inside a `catch_unwind` with the hook installed and asserts one line landed; RideTests: pure `ReportStore` (list, prune to 20, newest-first, acknowledged filter) with tests on a temp dir.
- Gates: engine gates, `scripts/build-engine.sh`, xcodebuild build test.

## P-4 `ride` command — Tier B

- `Info.plist` gains `CFBundleDocumentTypes` for folders (`public.folder`) and source files (`public.source-code`, `public.plain-text`) and a `CFBundleURLTypes` entry for the `ride` scheme. `RideAppDelegate` implements `application(_:open:)`: a folder opens as the workspace (or focuses it when already open); a file opens its workspace root (nearest ancestor with `Cargo.toml`, `CMakeLists.txt`, `Makefile` or `compile_commands.json`, else the file's directory) and the file; a `ride://open?path=<percent-encoded>&line=N&column=M` URL does the same and places the caret. Move the `value(after:)` argument helper out of `DemoLaunch` into a shared `LaunchArguments` used by `--open` too (`AppState+Launch.swift` has a copy).
- `app/Resources/ride` (installed into `Ride.app/Contents/Helpers/ride` by a copy phase): a POSIX sh script `ride [path[:line[:column]]]` (default `.`) that resolves the absolute path and runs `open -a Ride "ride://open?path=…&line=…&column=…"` (URL-encodes with `printf`/`od`, no python). Preferences › Tools gains "Install `ride` command" which creates the symlink `/usr/local/bin/ride` through `osascript -e 'do shell script "…" with administrator privileges'` (creating `/usr/local/bin` if needed) and shows the result; "Installed" when the link already resolves to this app.
- Tests: RideTests pure `WorkspaceRootFinder` (given a path and a set of existing files, returns the root) and `OpenURLParser` (`ride://` parsing, bad input → nil) with tests. Self-test: a Rust step (END) calling the delegate's open path with a `ride://open?path=<sample>/src/util.rs&line=3` URL and asserting the active buffer and caret line.
- Gates: xcodebuild build test, Rust self-test alone `EXIT 0`.

## P-5 C and C++ live verification — Tier B

- C++ debug steps appended to the END of the C++ self-test array (`SelfTestSteps+Cpp.swift` is over 200 lines: put them in `SelfTestSteps+CppDebug.swift`): set a breakpoint in `Circle::area` (`samples/cpp-demo/src/shapes.cpp`), Debug (⌃⌘R) the demo target, wait for the stop with the `until:` idiom (30 s), assert the stopped line and that the Debug panel lists a frame in `Circle::area`, expand a `std::vector` local and assert a child count, Step Out and assert the line moved to the caller, Stop. Mirror the existing Rust debug steps (`SelfTestSteps+Debug.swift`, `+DebugPanel.swift`). Skip with a PASS and a "developer mode disabled" note when `DeveloperMode.isEnabled` is false, exactly as the Rust steps do.
- C: a `--file src/main.c` self-test on `samples/c-demo` exercising build, run, a build diagnostic and Recompile File; `SelfTestSteps.all` dispatches `.c` to a C array that reuses the shared steps.
- CI: `engine.yml` `selftest` job adds `sudo DevToolsSecurity -enable` before the runs and a third run on `samples/c-demo`.
- Feature inventory: update `docs/product/feature-inventory.md` rows from built to live where the steps prove it (this card may edit that file).
- Gates: xcodebuild build test, then alone: Rust, C++ and C self-tests `EXIT 0`.

## P-6 Editor leftovers — Tier A

- Line endings preference `lineEndings` (`keep` default, `lf`): on save with `lf`, `BufferDocument` writes `\n` even when the file loaded as CRLF and flips `usesCRLF`; the status bar segment becomes a menu with Keep / Convert to LF for the buffer.
- Tree New File: `TreeActions.newFile(in:)` uses the save panel's `SaveLanguagePicker` list as a popup in the prompt (default Rust for a Cargo workspace, C++ for CMake, C for Makefile, from the project model kind), naming `untitled.<ext>`.
- Move Statement Up/Down (⇧⌘↑ / ⇧⌘↓, check collisions): swap the statement containing the caret with the previous/next sibling statement from the engine (`Engine::statement_bounds(session_id, byte) -> Option<(ByteRange, Option<ByteRange>, Option<ByteRange>)>` for current, previous, next), applied through `EditorCommand.apply` as one undo step, caret moving with the statement; refuse silently at the first/last statement.
- Tests: RideTests for the line-ending decision; `src/highlight` unit tests for statement bounds in Rust and C; self-test steps for Move Statement (END of both arrays).
- Gates: engine gates, `scripts/build-engine.sh`, xcodebuild build test, Rust and C++ self-tests alone.

## P-7 Site and manuals — Tier A

- `docs/site/index.html` + `docs/site/site.css`: a single static page (no build step, no JS) with the README's sections and the 22 images referenced relatively (`../images/…`), a download button pointing at `https://github.com/ReOpsIL/ride/releases/latest`, the cask one-liner, and the requirements. `.github/workflows/pages.yml` publishes `docs/site` and `docs/images` to GitHub Pages on pushes to `main` (`actions/upload-pages-artifact` + `deploy-pages`).
- `docs/manuals/shortcuts.md` generated from `Shortcuts.entries`: a RideTests test renders the entries as a markdown table and compares with the committed file; when the env var `RIDE_WRITE_MANUALS` is set it writes the file instead. `scripts/manuals.sh` runs that test with the variable set.
- `docs/manuals/getting-started.md` (install, open a project, the daily loop) and `docs/manuals/tutorial-{rust,c,cpp}.md` from the three sample READMEs (which stay as they are).
- `docs/README.md` gains the manuals and site rows (allowed for this card).
- Gates: xcodebuild build test (the shortcuts test green), `actionlint` if installed.

## P-8a Hygiene gates — Tier A

- Latency: `tests/latency.rs` (ignored in debug: `#[cfg_attr(debug_assertions, ignore)]`) opens the fixture engine from `tests/samples.rs`, runs 50 completions per site (identifier, member access, `use` path, include, struct literal) after 5 warm-ups, asserts p95 under 5 ms and editor queries (`highlight`/`outline` on the demo file) p95 under 1 ms; CI job `latency` runs `cargo test --release --test latency`.
- Index size: `tests/index_size.rs` builds the fixture index and asserts bytes per document under 600 (today's live ratio is about 520 at 1.74M docs / 900 MB); prints the numbers.
- File length: `scripts/check-lines.sh` lists non-generated `.rs`/`.swift` files over 220 lines (excluding `app/generated/`, `tests/`, `app/RideTests/`) and exits 1 when any exist; CI job `lines` runs it. Until P-8b lands, the script takes an allowlist file `scripts/check-lines.allow` naming the 7 known files so the gate is green now and tightens as they are split.
- Gates: engine gates, the three new tests locally (`cargo test --release --test latency --test index_size`), `bash scripts/check-lines.sh`.

## P-8b Split the seven files — Tier A, runs alone after batch B

`src/generate/rust.rs` (266), `app/Ride/Debug/SelfTestSteps+Rust.swift` (251), `app/Ride/Debug/SelfTestSteps+Cpp.swift` (248), `app/Ride/Editor/RideTextView.swift` (241), `src/generate/mod.rs` (240), `app/Ride/AppState.swift` (228), `app/Ride/RootView.swift` (227): split each by responsibility (the todo file names the seams: `RideTextView` apply helpers, `AppState` overlay flags, `RootView` `DetailColumn`, the self-test arrays into per-group files, generators per kind), register new Swift files in the pbxproj, empty `scripts/check-lines.allow`. No behaviour change; gates: engine gates, xcodebuild build test, `bash scripts/check-lines.sh` with an empty allowlist, Rust and C++ self-tests alone.

## Log

| Card | What landed | Merge |
|---|---|---|
| P-7 | `docs/site` static page and Pages workflow (reviewer fix: served at the root URL, image paths rewritten at assembly), `docs/manuals` (getting started, shortcuts generated from `Shortcuts.entries` by a RideTests test, three tutorials) | merge |
| P-1 | Version 1.0.0, `CHANGELOG.md`, `release.sh --dry-run` with version agreement, dSYM and RELEASE.md, tag-triggered `release.yml` with optional secrets and a GitHub release, Homebrew cask and bump script | merge |
