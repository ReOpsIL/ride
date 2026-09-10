# Cheat sheet popup (2026-09-10)

Status (2026-09-10): implemented. Sheets: Rust 30 sections / 710 entries, C++ 30 / 586, C 21 / 399, Makefile 14 / 242. Engine tests in `tests/cheatsheet.rs`, app tests in `app/RideTests/CheatSheetRowsTests.swift`, demo scene `cheatsheet`.

Goal: while the user types in a Rust, C, C++ or Makefile buffer, a second popup shows the part of the language cheat sheet that fits the caret (items at file level, statements in a body, patterns in a `match` arm, functions inside `$(`), each entry a template the user can insert as a snippet. The sheet is data, not code: one TOML file per section under `cheatsheets/<lang>/`, embedded in the engine, so extending the sheet never touches Rust or Swift.

## Model

| Piece | Where | Responsibility |
|---|---|---|
| `Context` | `src/highlight/context/` | Where the caret is syntactically: `Item`, `Body` (impl/trait/class body), `Fields` (struct/enum body), `Statement`, `Expression`, `Type`, `Pattern`, `Attribute`, `Preprocessor`, `Use`, `Recipe`, `Function`, `Value`, `Unknown`. One detector per grammar (`rust.rs`, `c.rs` for C and C++, `make.rs`), wired through `Grammar.context` like the site classifier, tree-sitter ancestors first and a brace-depth text scan when the caret sits in an `ERROR` node. |
| Sheet data | `cheatsheets/<lang>/<section>.toml` | `title`, `contexts = [...]` (empty or omitted means any), `[[entries]]` with `name`, `keys` (lowercase match words), `doc` (one sentence), `snippet` (tab-stop syntax `${1:text}` / `$0`, four-space indent, first line unindented). |
| Loader | `src/cheatsheet/{model,load,sheets/*}.rs` | `include_str!` tables per language, parsed once into `Sheet` behind `OnceLock`. |
| Lookup | `src/cheatsheet/lookup.rs` | Sections whose `contexts` contain the caret context come first in file order; with a typed prefix every section is filtered to entries whose name, name words or keys start with it, and non-context sections with matches follow. `all = true` ignores the context. Snippets are indented like the caret line (`engine/snippets.rs::render`). |
| FFI | `Engine::cheat_sheet(session_id, cursor_byte, all) -> CheatSheetResponse` | Reuses the session's `site_at` (prefix, replace start, comment/string veto) and `context_at`; `Site::Attribute` / `Include` / `Directive` / `UsePath` override the context. Returns `sections`, `replace_start_byte`, `prefix`, `context`. |
| CLI | `ride-engine cheat <file> [--byte N \| --find anchor] [--typed text] [--all]` | Prints the context and sections so the sheet can be probed without the app. |
| App | `app/Ride/CheatSheet/` | `CheatSheetController` (singleton, auto/pinned modes, fetch with query-id gating), `CheatSheetPopup` (panel, table of header and entry rows, preview pane, footer), `CheatSheetRows` (flatten sections, step over headers), `CheatSheetPlacement` (stacked on the far side of the completion popup, else at the caret), `CheatSheetRowView`, `CheatSheetPreview`, `CheatSheetFetch`. `SnippetInsert` is shared with completion accept. |

## Interaction

- Auto mode (preference "Cheat sheet with completions", on by default): the sheet appears with the completion popup whenever the caret context yields entries, narrows with every keystroke, and hides with the popup.
- Pinned mode: `⌃⇧Space` opens the sheet on demand (also without completions) and keeps it while the caret moves; a second `⌃⇧Space` or `esc` closes it.
- Keys while the completion popup is also visible: `⌥↑` / `⌥↓` move the sheet selection, `⌥↩` inserts the selected template; plain arrows and return still drive the completion list. With the sheet alone, arrows, return and tab act on it.
- Click a row to insert. Insertion replaces the typed prefix with the template and starts a snippet session (tab stops, `⇥` / `⇧⇥`).
- Placement: below the completion popup when the popup is below the caret, above it when the popup sits above the caret; alone, like the completion popup at the caret.

## Sheets

| Language | Sections |
|---|---|
| Rust | items, control flow, bindings and patterns, types, traits and generics, closures and iterators, error handling, ownership and smart pointers, strings and collections, modules and attributes, macros, concurrency and async, unsafe and FFI, tests and docs, I/O and process, expressions and literals |
| C++ | items and classes, control flow, types and declarations, templates and concepts, STL containers, algorithms and ranges, smart pointers and RAII, lambdas and functional, strings and streams, exceptions and errors, preprocessor and modules, concurrency, expressions and casts, class special members |
| C | items and functions, control flow, types and declarations, pointers and arrays, structs unions enums, preprocessor, strings and memory, I/O and files, storage and qualifiers, C11 and C23 features, expressions and operators |
| Makefile | rules and targets, variables, automatic variables, functions, conditionals and directives, recipes and shell, special targets, pattern rules and VPATH |

## Tests

- `tests/cheatsheet.rs`: every sheet parses, every context name is valid, every snippet has balanced tab stops and non-empty name and doc; caret-marker fixtures per language assert the detected context; lookup narrows by prefix and ranks context sections first.
- `app/RideTests/CheatSheetRowsTests.swift`: rows flatten with headers, stepping skips headers, placement picks the far side of the completion frame.

## Limits

- Context detection is syntactic; it does not know the type of an expression, so `Expression` shows the same sections after `x.` regardless of `x`.
- TOML and CMake buffers have no sheet yet; the popup stays hidden there.
