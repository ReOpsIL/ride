# Diagnostic overlay

| Field | Value |
|---|---|
| Status | Spec, not built |
| Scope | Rust diagnostics from `cargo check`, clippy, live checks and Cargo builds |
| Engine | `src/check/` parser and `src/ffi/check.rs` records |
| App | Editor decorations (`DecoratedFragment`), gutter, `DiagnosticStore` |

## 1. What it is

A compiler message usually names more than one place. A borrow error names where the value was borrowed, where it was changed and where the borrow was used again. A lifetime error also names where the value was dropped. A type mismatch names the expression and the annotation that set the expectation. rustc sends every one of these places as a labelled span.

Today Ride keeps only the primary span. The message becomes one underline and one line of text in the Problems panel, and the reader has to rebuild the rest from the terminal output.

The overlay draws the whole message on the code. Each labelled span gets an underline and a label under its own line. A number in the gutter shows the order. Notes and help lines appear under the primary label, and an applicable fix is one click away.

## 2. What the user sees

![The overlay at the caret on E0382: the three spans of the error numbered 1 to 3 in the gutter with a label under each, the note and help rows under the primary label with a Fix chip, and the two spans the note names on line 10 underlined dashed with their own labels](../images/diagnostic-overlay.svg)

The labels in the image are rustc's own, from a real `cargo check` of that code. The note names two places on line 10, which is why child messages carry spans too (section 8.2).

The same layout in text, for E0597:

```
 4 1     let s = String::from("hi");
           ▲ binding `s` declared here
 5 2     r = &s;
             ▲ borrowed value does not live long enough
 6 3 }
     ▲ `s` dropped here while still borrowed
 7 4 r.len()
     ▲ borrow later used here
       help: … · note: …
```

| Element | Drawn as |
|---|---|
| Primary span | Wavy underline in the level colour, as today. Its label chip uses the level colour |
| Secondary span | Solid underline in the neutral accent colour. Its chip uses the same colour |
| Label | A chip under the line, starting at the span's column. The text is rustc's label, verbatim |
| Order | A number in the gutter on each labelled line, `1` to `n` |
| Multi-line span | A bracket in the gutter from the first line to the last. The label sits under the last line |
| Empty span | A caret mark at the position, with the chip under it |
| Notes and help | One dim row under the primary chip per child message, prefixed `note:` or `help:`. When the child names places in the file, the row ends with `↓ line N`, which jumps to the first one |
| Span named by a note or help | Dashed underline in the note colour with its own chip. Not numbered |
| Applicable fix | A `Fix` chip at the end of the help row. It runs the fix that ⌥↩ already offers |
| Span in another file | A chip on the primary line: label, then `↗ file:line`. A click opens Quick Definition at that place |
| Span inside a macro | Mapped to the outermost call site in the open file. The chip ends with `in name!` |

Span without a label: underline and gutter number only. Message without any span (linker errors, missing native libraries): no overlay, the Problems panel stays the only place.

## 3. When it shows

| Mode | Behaviour |
|---|---|
| Off | Underlines and gutter dots only, as today |
| At caret (default) | The overlay of the diagnostic whose primary or secondary span contains the caret, or whose primary line holds the caret |
| All in file | Every diagnostic in the open file |

The mode is a preference under Editor, mirrored in View › Diagnostic Overlay, with a shortcut to cycle it. Selecting a row in the Problems panel opens the overlay of that diagnostic, whatever the mode. Esc hides the active overlay until the caret leaves its lines.

At caret is the default because a real file with several errors becomes unreadable when every label is drawn. When two diagnostics compete at the caret, the error wins over the warning, then the narrower primary span wins.

## 4. Order

The gutter numbers follow source position: the byte offset of each span of the message, primary included. Spans named by notes and help are not numbered. rustc gives each span a role in its label text, not an order, and the label text is not a stable interface. The overlay does not parse it.

A diagnostic with one labelled span shows no numbers.

## 5. Layout rules

1. A chip belongs to the line that holds its span's end for multi-line spans, and its start otherwise.
2. Chips for one line are placed left to right in one row while they do not overlap. A chip that would overlap moves to the next row. Rows are ordered by the column of their first chip.
3. Label rows are extra height under the line, the same mechanism ghost text uses (`DecoratedFragment.bottomMargin`). The text itself never moves sideways.
4. On a line that also shows ghost text, the ghost rows come first and the label rows follow.
5. Code vision rows stay above the line (`topMargin`) and are unaffected.
6. A span inside a folded region attaches its chip to the fold's visible line, and its gutter number shows on that line.
7. A chip wider than the visible text area is truncated with an ellipsis. Its full text is a tooltip.
8. Each split pane lays out its own overlay. The active diagnostic follows each pane's caret.

## 6. Freshness

Spans come from the last check, so the overlay follows the same rules as the underlines it extends.

- **Edits outside a span.** Every label shifts with the edit (`RangeShift`), like the underlines do today.
- **Edits inside a labelled span.** The whole overlay of that diagnostic is marked stale and hidden. Its underlines stay until the next check result replaces them.
- **A new check result.** It replaces the overlay. Results are matched by `CheckService.version`, the same key `Underlines` uses.
- **A file that changed on disk.** Its overlays are dropped with its diagnostics.

A stale overlay is never drawn. A label pointing at text that has changed is worse than no label.

## 7. Interaction

| Action | Result |
|---|---|
| Click a chip | Caret to the start of that span |
| Click a gutter number | Same as clicking its chip |
| Click a `↗` chip | Quick Definition at the external span |
| Click `Fix` | Applies the fix through the intention path, one undo group |
| Hover a chip | Full label, plus the error code with its documentation link (`DiagnosticDocLink`) |
| Esc | Hides the active overlay until the caret leaves its lines |

## 8. Engine

### 8.1 The broken invariant

`check/parse.rs` turns one compiler message into one `Diagnostic` per primary span and drops the non-primary spans and every label. The `Span` struct in `check/message.rs` does not deserialize `label`, `line_end`, `column_end` or `expansion`. Child messages are read only to build fixes. A `Diagnostic` therefore cannot say what rustc said. The fix is in the record, not in the drawing.

### 8.2 Records

```rust
pub struct DiagnosticLabel {
    pub path: String,
    pub byte_start: u32,
    pub byte_end: u32,
    pub line_start: u32,
    pub line_end: u32,
    pub column: u32,
    pub text: Option<String>,
    pub macro_name: Option<String>,
}

pub struct DiagnosticNote {
    pub level: DiagnosticLevel,
    pub message: String,
    pub labels: Vec<DiagnosticLabel>,
}

pub struct Diagnostic {
    pub level: DiagnosticLevel,
    pub message: String,
    pub code: Option<String>,
    pub primary: DiagnosticLabel,
    pub secondary: Vec<DiagnosticLabel>,
    pub notes: Vec<DiagnosticNote>,
    pub fixes: Vec<DiagnosticFix>,
}
```

Invariants:

- A `Diagnostic` has exactly one primary label, a field rather than a flag, so a diagnostic without a primary span cannot be built.
- A message with several primary spans still yields one `Diagnostic` per primary span, as the Problems panel expects. Each one carries the message's non-primary spans as `secondary`. Other primaries are not repeated.
- `secondary` is in source order within a file. Labels in other files follow, grouped by file.
- A label inside a macro carries the outermost call-site span that lies in a workspace file, and the macro's name. A label whose expansion chain never reaches a workspace file keeps its own span, marked external by its path.
- `notes` hold every child message, in rustc's order. A child's spans become its `labels`, under the same rules as `secondary`. A span that only carries a suggestion and no label stays out of `labels`. A child with an applicable suggestion also yields a `DiagnosticFix`, as today.

`path`, `byte_start`, `line` and `column` of today's `Diagnostic` move into `primary`. Dedup in `check/dedup.rs` keys on the primary label.

### 8.3 Modules

| Module | Does |
|---|---|
| `src/check/message.rs` | Deserializes the extra span fields and `expansion` |
| `src/check/labels.rs` | Span to `DiagnosticLabel`, absolute paths, macro call-site walk |
| `src/check/notes.rs` | Child messages to `DiagnosticNote`, with their labelled spans |
| `src/check/parse.rs` | Orchestration only: level, primary split, labels, notes, fixes |
| `src/ffi/check_labels.rs` | `DiagnosticLabel`, `DiagnosticNote` |

`engine/build_output.rs` calls `parse_message_line` and gains the labels with no change of its own.

### 8.4 CLI probe

`ride-engine check <root> [--clippy] [--file <path>]` runs the check and prints each diagnostic with its primary and secondary labels, notes and fixes, one line per label. It lets the parser be checked against a real crate without the app.

## 9. App

| Piece | Does |
|---|---|
| `StoredDiagnostic` | Carries `primary`, `secondary` and `notes`. `CheckConvert` maps both ways |
| `Overlay/OverlayModel.swift` | Pure: one diagnostic plus the line index gives the placed chips, rows and gutter numbers (section 5) |
| `Overlay/OverlaySelection.swift` | Pure: the caret, the mode and the file's diagnostics give the active set (section 3) |
| `Overlay/OverlayRows.swift` | The decoration that `DecoratedFragment` draws in its bottom margin, beside `ghost` |
| `Overlay/OverlayShift.swift` | Shifts labels with an edit, marks a diagnostic stale when an edit enters a span |
| `GutterView` | Draws numbers and multi-line brackets next to today's diagnostic dots |
| `Underlines` | Draws secondary underlines from the same store |

Changing the active overlay changes fragment heights. It must refresh the affected paragraphs the way `docs/tui/editor-fragment-refresh.md` describes, or TextKit 2 keeps the old layout. The pure files go into the RideTests Sources phase.

## 10. Tests

| Level | Covers |
|---|---|
| Engine, `tests/check.rs` | Recorded rustc JSON lines: E0382 with three labels, a note naming two spans and a help with a machine-applicable fix, E0597 with four labels, E0502 with three, E0308 with an expectation span, `unreachable_code` with a secondary span, unused imports with two primary spans, a label inside `println!`, a span inside the standard library |
| RideTests | Row packing, ordering, folded spans, shift on edit, stale on an edit inside a span, the caret selection rules |
| Self-test | A copy of `samples/rust-demo` with an injected borrow error. The caret on the error shows its rows and gutter numbers. Clicking a chip moves the caret. Typing inside a span hides the overlay. The View item and the preference are claimed by these steps for the menu coverage gate |

## 11. Not in this spec

- C and C++. clang's notes carry locations too, but its text output has no labels. That needs its own parser work.
- Diagnostics from rust-analyzer. Its server runs with diagnostics off.
- Ordering by meaning rather than by position. That would need rules per error code, kept outside rustc's label text.
- Explanations beyond rustc's own text.
- A project-wide view of the overlays.

## 12. Done when

- Every rustc and clippy diagnostic with labelled spans shows all of them on the code, in the open file, at the caret.
- The recorded fixtures pass in the engine, and the CLI probe prints the same labels for a real crate.
- No stale label is ever drawn after an edit inside its span.
- Completion and typing latency gates in CI are unchanged with the mode on All in file.
