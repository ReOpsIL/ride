# Documentation index

| Topic | Where |
|---|---|
| Product and architecture spec | `plan/ride_draft.md` |
| Roadmap and phases | `plan/roadmap/improve-extend.md` |
| UI design plan and audit | `plan/roadmap/ui-design.md` |
| Historical engine notes | `plan/autocomplete.md` |
| Engine follow-ups | `todo/engine/remaining.md` |
| App follow-ups | `todo/app/remaining.md` |

## Engine layout

| Module | Responsibility |
|---|---|
| `src/discover` | `$CARGO_HOME` registry and git checkouts, rustc sysroot, `cargo metadata` |
| `src/extract` | tree-sitter item extraction with module paths, impls, re-exports |
| `src/index` | Tantivy schema, one-shot writer, generations, manifest, status and warnings logs |
| `src/query` | prefix / BM25 completion search, crate prefix, keyword hits |
| `src/highlight` | buffer sessions over a `Syntax` trait: Rust (tree-sitter-rust) and Markdown (tree-sitter-md block + inline); highlight deltas, outline, parse errors |
| `src/check` | `cargo check` JSON diagnostics and rustfmt |
| `src/engine` | in-process `Engine`: sessions, query routing, definitions, tools, manifest watch |
| `src/ffi` | UniFFI records, enums and listener traits |

## Index directory

```
manifest.json     schema_version, engine_semver, generation, live_dir, fingerprint, docs
gen-N/            live Tantivy index (previous generation is kept, older ones pruned)
staging-<pid>/    in-progress write, renamed to gen-N on success
status.jsonl      progress lines: state, docs, crates_done/total, warnings
warnings.jsonl    per-crate extraction errors of the last run
```

A run whose crate-set fingerprint matches `manifest.json` appends a `ready` status and writes nothing. `ride-engine index --force` or the app's Reindex menu bypasses the check.

## Engine surface used by the app

| Method | Purpose |
|---|---|
| `query_completions` | prefix / crate / phrase completions with context bias, best hit per name |
| `find_definitions` | identifier under the caret to buffer outline or index definitions |
| `run_check` | `cargo check` diagnostics with absolute paths and byte ranges |
| `format_rust` | rustfmt a buffer |
| `open_session` / `apply_edit` / `set_visible_range` | highlight deltas, outline, parse errors |

## Release

`scripts/release.sh` builds the engine, archives Ride.app in Release, signs it
(ad hoc unless `RIDE_SIGN_IDENTITY` is set), zips it under `target/release-app/`
and, when `RIDE_NOTARY_PROFILE` names a notarytool keychain profile, notarizes
and staples.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/build-engine.sh` | release engine for arm64, UniFFI Swift bindings, xcframework, `ride-engine` helper |
| `scripts/run.sh [folder]` | Debug build of Ride.app and open a folder |
| `scripts/install.sh [dest]` | check Xcode/rustup/rust-src, build engine and Release app, ad-hoc sign, install to /Applications |
| `scripts/release.sh` | Release archive, sign, zip, optional notarize |
| `scripts/make-icon.swift <out-dir>` | render the app icon set (`swiftc -O` it, run, then `iconutil -c icns`) |

## Screenshot review without input

`Ride.app --args --open <folder> --demo <scene> --frame 1440x900` drives the UI into a state (`editor`, `completion`, `hover`, `quickopen`, `symbols`, `find`, `problems`, `outline`, `light`) so it can be captured by window id. Scenes never write preferences or files.
