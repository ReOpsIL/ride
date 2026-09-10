# Must-have editor functionality (2026-09-10)

Status (2026-09-10): P0, P1, P1b, P2 and most of P3 implemented. Done: smart Enter, Tab/⇧Tab indent, comment toggle, bracket pairing, undo grouping; duplicate/delete/join/move/new line/case/sort, copy line and Copy Reference, extend/shrink selection, matching brace, find options and Find and Replace; New File with language picker, Open… for files, Close Workspace, Save All/As, Revert, Close All/Others, disk-change prompt, CRLF preserved and shown, tree and tab context items; Back/Forward, Last Edit, Go to Line, Recent Files, next/previous problem and method, header/source switch, zoom and view toggles; folding, Surround With, Quick Documentation and Signature Help on demand. Open: gutter fold chevrons and bracket-pair highlight, Reformat Selection, Move Statement, Complete Statement, Replace in Project, ⌫/↩ in the tree, Recent Locations. Verification: the `--demo selftest` scene runs 47 command checks in-process (all pass on the demo project) and the menu bar was enumerated through Accessibility to confirm every item and its enabled state. Tests: `tests/editing.rs` (engine), `app/RideTests` (LineOps, CommentToggle, SmartIndent, BracketPairing, NavigationHistory, SiblingSource, FindMatcher, FoldSet).

Priority: **before** `plan/roadmap/next.md`. Reference: RustRover's Edit, View, Navigate and Code menus ([quick start](https://www.jetbrains.com/help/rust/quick-start-guide-rustrover.html), [source code editing](https://www.jetbrains.com/help/rust/working-with-source-code.html), [navigation](https://www.jetbrains.com/help/rust/navigating-through-the-source-code.html), [reformat](https://www.jetbrains.com/help/rust/reformat-and-rearrange-code.html)).

## Audit: RustRover menus against Ride today

Ride's editor is a bare `NSTextView` with completion, snippets, hover, definitions, find/replace in file and project, symbol pickers, check and format. Everything a programmer reaches for between keystrokes is missing: the Edit menu is the macOS default (undo, clipboard, select all), Enter does not indent, Tab only inserts spaces, there is no comment toggle, no line operations, no bracket pairing, no go-to-line, no navigation history, no folding.

| RustRover item (mac shortcut) | Ride today | Verdict |
|---|---|---|
| **File** | | |
| New ▸ Rust File / File / Directory (⌘N in the tree), New Project | New Buffer (⌘N, untitled `.rs`); tree toolbar and context menu New File / New Folder with a name prompt | Must: ⌘N becomes New File in the selected folder with the save panel's language picker (todo item); New Folder in the File menu; New Buffer stays as ⌥⌘N |
| Open… (⌘O), Open Recent ▸, Close Project | Open Folder… (⌘O), Open Recent | Must: Open… accepts a file as well as a folder (opens the file inside its nearest workspace); Close Workspace |
| Save All (⌘S), Save As…, Reload All from Disk | Save (⌘S) | Must: Save All (⌥⌘S), Save As… (⇧⌘S), Revert to Saved / Reload from Disk when the file changed on disk (prompt instead of silent overwrite) |
| Close Tab (⌘W), Close All Tabs, Close Other Tabs | Close Editor (⌘W) | Must: Close All (⌥⌘W), Close Others; tab context menu |
| Rename (⇧F6), Delete (⌫), Copy / Paste file, Duplicate | tree context menu: Rename, Delete, Reveal in Finder | Must: Duplicate, Copy Path / Copy Relative Path (⇧⌥⌘C already lists `path:line`), Open in Terminal; keyboard: ⌫ deletes, ↩ renames in the tree |
| File Properties ▸ Line Separators, Encoding, Read-only | none (UTF-8, LF assumed) | Must-lite: status bar shows `LF`/`CRLF`; convert on save preference; files with invalid UTF-8 open read-only with a notice |
| Settings (⌘,) | Preferences (⌘,) | Fine |
| Local History, Invalidate Caches, Export, Print, Power Save | Reindex | Fine (Reindex covers the cache case) |
| **Edit** | | |
| Undo / Redo (⌘Z / ⇧⌘Z) | AppKit default; a snippet insert or format is many undo steps | Must: group each command into one undo step |
| Cut / Copy / Paste / Paste plain (⇧⌥⌘V) / Paste from history | Default cut/copy/paste; paste is already plain | Must: copy line when nothing is selected (⌘C on empty selection), cut line likewise. Later: paste history |
| Copy Reference (⇧⌥⌘C: `path:line`) | none | Must (cheap, useful for issues and chat) |
| Duplicate Line/Selection (⌘D) | none | Must |
| Delete Line (⌘⌫) | none | Must |
| Join Lines (⌃⇧J) | none | Must |
| Move Line Up/Down (⌥⇧↑ / ⌥⇧↓) | none | Must |
| Move Statement Up/Down (⇧⌘↑ / ⇧⌘↓) | none | Later (needs tree-sitter statement ranges; line move covers 80%) |
| Start New Line (⇧↩) / Start New Line Before (⌥⌘↩) | none | Must |
| Extend / Shrink Selection (⌥↑ / ⌥↓) | none | Must (engine: tree-sitter node ancestry) |
| Select Word / Line | double and triple click only | Must as commands (⌘D-style is taken; use ⌃W for word, ⌘L for line) |
| Toggle Case (⇧⌘U) | none | Must (trivial) |
| Sort / Reverse Lines | none | Nice |
| Column Selection Mode (⇧⌘8) / multiple carets (⌥⇧click, ⌃G add next occurrence) | none | Later (TextKit 2 supports multiple selection ranges; own phase) |
| Find / Replace (⌘F / ⌘R) | Find bar with replace one/all, next/previous | Must: Replace has its own shortcut; regex and match-case toggles; Use Selection for Find (⌘E) |
| Find in Project / Replace in Project | Find in project; no replace | Must: replace in project with preview |
| **View** | | |
| Tool windows (Project ⌘1, Structure ⌘7, Problems ⌘6) | Sidebar, Outline, Problems, Preview toggles | Fine; add ⌘1 / ⌘7 / ⌘6 aliases |
| Appearance: Zoom (⌘= / ⌘−, reset), Soft Wrap, Show Whitespace, Indent Guides, Line Numbers, Breadcrumbs | Font size in Preferences; whitespace and guides in Preferences | Must: Zoom In/Out/Reset in the menu; Soft Wrap toggle; whitespace and guides as menu toggles |
| Recent Files (⌘E), Recent Locations (⇧⌘E) | none | Must: Recent Files picker; Recent Locations later |
| Quick Documentation (F1), Quick Definition (⌥Space), Parameter Info (⌘P) | hover only; signature help on `(` | Must: Quick Documentation on demand (⌃J) reusing the hover card; Signature Help on demand (⇧⌘Space) |
| Enter Full Screen, Presentation Mode | macOS default full screen | Fine |
| **Navigate** | | |
| Class / File / Symbol (⌘O / ⇧⌘O / ⌥⌘O), Search Everywhere (⇧⇧) | Open Quickly, Go to Symbol in File/Project | Fine |
| Back / Forward (⌘[ / ⌘]) | none | Must: navigation history per window (every jump, definition, picker open, search result) |
| Last Edit Location (⇧⌘⌫) | none | Must (falls out of the history) |
| Go to Line:Column (⌘L) | none | Must |
| Declaration or Usages (⌘B), Type Declaration (⇧⌘B), Implementation (⌥⌘B), Super (⌘U) | F12 definition | Fine for 1.x; usages arrive with `next.md` 1.2-1 |
| Related Symbol / Header-Source switch (⌃⌥↑ in CLion) | none | Must for C/C++: switch between `.h` / `.c` / `.cpp` siblings |
| Next / Previous Highlighted Error (F2 / ⇧F2) | Problems panel click only | Must |
| Next / Previous Method (⌃↓ / ⌃↑) | none | Must (outline ranges already known) |
| Matching Brace (⌃M) | none | Must, plus highlight the pair under the caret |
| Bookmarks (F3 toggle, ⌘F3 list) | none | Nice |
| File Structure (⌘F12) | Outline panel and ⌘R picker | Fine |
| **Code** | | |
| Comment with Line Comment (⌘/) / Block Comment (⌥⌘/) | none | Must, per language (`//`, `/* */`, `#` for Make and TOML and CMake, `<!-- -->` for Markdown) |
| Reformat Code (⌥⌘L), Reformat File, Reformat Selection | Format Document (⌃⇧I) | Must: Reformat Selection through `rustfmt` / `clang-format --lines`; keep whole-file |
| Auto-Indent Lines (⌃⌥I) | none | Must |
| Indent / Unindent (Tab / ⇧Tab on a selection, ⌘] / ⌘[) | Tab inserts spaces; ⇧Tab does nothing without a snippet | Must |
| Smart Enter: indent on newline, dedent `}`, keep list/comment prefix | none | Must |
| Bracket and quote auto-close, type-over, wrap selection | none | Must |
| Surround With (⌥⌘T) | none | Must-lite: wrap selection with `{}`, `()`, `if`, `for`, `match`, `unsafe`, `loop`, `/* */`, `#if 0` from the cheat sheet data |
| Complete Current Statement (⇧⌘↩) | none | Nice: add `;` or `{}` and move to the next line |
| Unwrap / Remove (⇧⌘⌫) | none | Later |
| Folding (⌘+ / ⌘−, ⇧⌘+ / ⇧⌘−) | none | Must: fold items and blocks from tree-sitter ranges, gutter chevrons |
| Optimize Imports (⌃⌥O) | auto-import on accept only | Later: remove unused `use` needs usage data (1.2-1) |
| Generate (⌘N), Code Cleanup, Inspect Code, Intention Actions (⌥↩) | none | Later (`next.md` 1.2-7 quick fixes) |
| Cheat sheet, Trigger Completion (⌃Space) | present | Add both to the Code menu so they are discoverable |

## Design

**Where the logic lives.** Every command that is a pure text transform (line and selection operations, indent, comment, join, case, duplicate, bracket pairing) is a static function in `app/Ride/Editing/` taking `(text: String, selection: NSRange, options)` and returning `(replacement edits, new selection)`, applied through one `EditorCommand.apply` that wraps the change in a single undo group and routes it through `replaceText` so the engine session, underlines and completion stay in sync. These files join the `RideTests` target (they must not reference generated FFI types; see `ride-tests-target-layout`). Commands that need syntax (extend selection, fold ranges, matching brace, statement ranges, auto-indent depth, comment tokens per language, header/source siblings) come from the engine as small session queries, tested with caret-marker fixtures in `tests/`.

**Engine additions** (`src/highlight/`, exposed on `Engine`):

| Call | Returns | Used by |
|---|---|---|
| `comment_tokens(lang)` | line and block comment markers | comment toggle, surround |
| `enclosing_ranges(session, byte)` | the chain of tree-sitter node ranges around the caret, innermost first | extend/shrink selection, surround |
| `fold_ranges(session)` | byte ranges of items, blocks, `#if` regions, multi-line comments | folding, gutter chevrons |
| `indent_at(session, byte)` | indent string for a new line at `byte` (brace depth, `case`/`=>` bodies, continuation lines) | smart Enter, auto-indent lines |
| `bracket_pair(session, byte)` | the matching bracket for the one at or before the caret, string/comment aware | matching brace, pair highlight |
| `statement_range(session, byte)` | the statement or item around the caret | move statement, complete statement |
| `sibling_source(path)` | `.h` ↔ `.c`/`.cpp` candidate paths | header/source switch |

**Keymap.** RustRover's mac defaults where they do not fight the macOS text system; the Keyboard Shortcuts panel and menus list them. Conflicts resolved: Ride's Find Next stays ⌘G (macOS), so Go to Line is ⌘L; extend selection ⌥↑ / ⌥↓ is free when no popup is open (the cheat sheet uses it only while both popups are visible); Back/Forward ⌘[ / ⌘] so Indent/Unindent are Tab / ⇧Tab on a selection and ⌘] / ⌘[ are **not** reused; Duplicate is ⌘D; Delete Line ⌘⌫; Move Line ⌥⇧↑ / ⌥⇧↓; Comment ⌘/ (the Keyboard Shortcuts help panel moves to ⌘?).

**Menu layout.** Edit and View gain the missing items; a new **Navigate** menu takes Open Quickly, Recent Files, Back/Forward, Last Edit, Go to Line, Symbol pickers, Definition, Header/Source, Next/Previous Problem and Method, Matching Brace; a new **Code** menu takes Comment, Indent, Reformat, Auto-Indent, Surround, Fold, Move Line/Statement, Complete Statement, Trigger Completion, Cheat Sheet, Quick Documentation, Signature Help. Menus observe `MenuModel` only (see the menu-rebuild fix); enabled state comes from a few published flags (has editor, has selection).

## Phases

### P0 — Typing basics (5 days)

| # | Item | Notes |
|---|---|---|
| P0-1 | Smart Enter | New line takes the current indent; after `{`, `(`, `[`, `=>`, `:` (Make recipe start) add one level; typing `}` on a whitespace-only line dedents; Enter between `{}` opens a block with the caret on the middle line; comment prefix continues for `///`, `//!`, `*` inside `/* */`, `#` in Make/TOML |
| P0-2 | Indent / Unindent | Tab and ⇧Tab on a selection shift whole lines by `tabWidth` (spaces; tabs in Makefiles); Auto-Indent Lines (⌃⌥I) rewrites indent from `indent_at`; Tab with no selection and no snippet keeps inserting |
| P0-3 | Comment toggle | ⌘/ toggles line comments on every selected line at the common indent, uncomments when all are commented; ⌥⌘/ wraps or unwraps a block comment; per-language tokens from the engine |
| P0-4 | Bracket and quote pairing | Auto-close `()[]{}` and `""` (not `'` in Rust lifetimes, not inside strings/comments), type-over the closing one, backspace deletes the pair, a selection gets wrapped; preference to turn off |
| P0-5 | Undo grouping | Every command above is one undo step; snippet insertion and auto-import are one step; formatting is one step |

### P1 — Line and selection commands (4 days)

| # | Item | Notes |
|---|---|---|
| P1-1 | Duplicate (⌘D), Delete Line (⌘⌫), Join Lines (⌃⇧J), Move Line Up/Down (⌥⇧↑/↓), Start New Line (⇧↩), New Line Before (⌥⌘↩), Toggle Case (⇧⌘U), Sort Lines | pure transforms with tests; move keeps the selection on the moved lines |
| P1-2 | Copy / Cut line when nothing is selected; Copy Reference (`src/main.rs:12`) | |
| P1-3 | Extend / Shrink Selection (⌥↑ / ⌥↓), Select Word (⌃W), Select Line (⌘L when the Go to Line field is not focused: use ⇧⌘L) | `enclosing_ranges` from the engine; word → node → statement → block → item → file |
| P1-4 | Matching Brace (⌃M) and pair highlight under the caret | `bracket_pair`; highlight as a rendering attribute like the current line |
| P1-5 | Find bar: Replace shortcut (⌥⌘F), match case, whole word, regex toggles, Use Selection for Find (⌘E), match count already present | |

### P1b — File menu (2 days)

| # | Item | Notes |
|---|---|---|
| P1b-1 | New File… (⌘N) with language picker in the selected tree folder; New Folder…; New Buffer (⌥⌘N) | reuse `SaveLanguagePicker` |
| P1b-2 | Open… accepts files; Close Workspace; Save All (⌥⌘S); Save As… (⇧⌘S); Revert to Saved; reload prompt when the file changed on disk | `FileWatcher` already reports paths; compare mtime at save |
| P1b-3 | Close All (⌥⌘W), Close Others; tab context menu with Close, Close Others, Reveal in Finder, Copy Path | `TabStrip` |
| P1b-4 | Tree: Duplicate, Copy Path, Copy Relative Path, Open in Terminal; ⌫ deletes, ↩ renames | `TreeActions` |
| P1b-5 | Line ending shown in the status bar; CRLF files keep CRLF on save | `BufferDocument` |

### P2 — Navigation (4 days)

| # | Item | Notes |
|---|---|---|
| P2-1 | Navigation history: Back / Forward (⌘[ / ⌘]) and Last Edit Location (⇧⌘⌫) | a per-window ring of `(file, byte)` recorded on every jump, picker result, search hit, tab switch; edits push the edit location |
| P2-2 | Go to Line:Column (⌘L) | small overlay like Open Quickly |
| P2-3 | Recent Files (⌘E) | picker over the open-order list, Enter switches |
| P2-4 | Next / Previous Problem (F2 / ⇧F2), Next / Previous Method (⌃↓ / ⌃↑) | from Problems and outline ranges |
| P2-5 | Header / Source switch (⌃⌥↑) | `sibling_source`; opens the sibling in the same pane, or the other pane once the split lands |
| P2-6 | Menu aliases ⌘1 Project, ⌘6 Problems, ⌘7 Outline; Zoom In/Out/Reset (⌘= / ⌘− / ⌃⌘0); Soft Wrap, Show Whitespace, Indent Guides as View toggles | |

### P3 — Structure (5 days)

| # | Item | Notes |
|---|---|---|
| P3-1 | Folding | `fold_ranges`; gutter chevrons; Fold / Unfold (⌘− / ⌘=... use ⌥⌘← / ⌥⌘→ to keep zoom on ⌘−/⌘=), Fold All / Unfold All (⇧⌥⌘← / →); folded placeholder `{ … }`; TextKit 2 layout fragment hiding |
| P3-2 | Surround With (⌥⌘T) | popup listing wrappers from the cheat sheet (`contexts = ["surround"]` entries with `${SELECTION}`), plus brackets and comments |
| P3-3 | Reformat Selection, Move Statement Up/Down, Complete Current Statement | `clang-format --lines`, `rustfmt` on the enclosing item as a fallback; `statement_range` |
| P3-4 | Quick Documentation (⌃J) and Signature Help on demand (⇧⌘Space) in the Code menu | reuse hover card and signature popup |
| P3-5 | Replace in Project with preview | extends Find in Project |

Total: about 20 working days. P0 alone removes the "this is not an editor yet" feeling and should ship first as 1.0.1.

## Tests

- `RideTests/EditingTests`: every pure transform (indent, unindent, comment toggle line/block for each language, duplicate, delete, join, move up/down at file edges, case, sort, start new line) on fixtures with `|` caret and `[ ]` selection markers; undo produces the original text.
- `RideTests/BracketPairingTests`: auto-close, type-over, backspace pair, wrap selection, no pairing inside strings and comments.
- `tests/editing.rs` (engine): `indent_at`, `enclosing_ranges`, `fold_ranges`, `bracket_pair`, `statement_range`, `sibling_source` with caret-marker fixtures for Rust, C, C++, Make, TOML, Markdown.
- Demo scenes `folding`, `surround`, `gotoline` for screenshot review; the app integration test (next.md 1.1-10) drives ⌘/ and Tab on `samples/cpp-demo`.

## Deferred on purpose

Multiple carets and column selection (own phase after P3; TextKit 2 supports multiple selection ranges but every command above must become range-list aware first), Paste from History, bookmarks, Unwrap/Remove, Optimize Imports and intention actions (need usage data and diagnostics from `next.md` 1.2), Move Element Left/Right.
