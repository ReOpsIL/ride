# Ride — Build plan for support 2027 v2

| Field | Value |
|---|---|
| Date | 2026-10-11 |
| Status | The order to build |
| Spec | `plan/roadmap/support-2027-v2.md`. §0.1 of that file is binding. A row there is not a card here |
| Floor | `plan/roadmap/progress-2026-10.md` continues beside this. Nothing here deletes one of its cards |

The first slice is the two ideas that can go wrong quietly: the shape hash, and equivalence. Marks sit on that hash, so they land in the same slice. The inbox is the first thing a person sees. Hunt, notes, and hand-off wait until a branch can be read as behaviour.

## What the engine can already prove

| Fact | Where it lives |
|---|---|
| An item's span, name, kind, signature text, doc | `OutlineItem` |
| Which item contains a byte | Innermost outline span |
| A call's bare name and the bare name of the item that contains it | `RefRecord` |
| Hunks with old and new line numbers | `src/git/diff_parse.rs` |
| A blob at `HEAD` or the index | `src/git/blob.rs`. An arbitrary commit is `git show REV:path`, a small extension |
| Diagnostics of the working tree | `cargo` and `clang` checks |

A proof that needs a resolved callee, or a build of the base revision, is a hold. See §0.1.

## Slice A — Symbol diff, hash, equivalence

Engine only. Tests in `tests/review.rs`. No panel yet.

| Module | Does |
|---|---|
| `src/review/item_id.rs` | File, enclosing-name chain, kind, signature text when the chain collides |
| `src/review/shape_hash.rs` | Leaf tokens in order. Whitespace dropped. Rust `///`, `//!`, `/**` kept. Every C and C++ comment dropped |
| `src/review/outline_pair.rs` | Parse the old blob and the new text. Two outlines |
| `src/review/hunk_assign.rs` | Each hunk to the innermost item whose span contains it |
| `src/review/equivalence.rs` | Two proofs, and nothing else |

Proofs:

- **Formatting.** The shape hashes are equal. `cargo fmt` and `clang-format` over a scratch branch produce zero behaviour rows.
- **Move.** One item removed and one item added, same shape hash, and no second item in the crate shares that hash. Otherwise both rows need eyes.

A file the grammar cannot outline stays one file hunk, labelled no outline. `.ride/` is not a review file.

Done when: a scratch repo yields body, signature, added, removed, and moved. One token changed inside each of 200 items leaves the equivalent group, every time. A non-code file stays a file hunk.

## Slice B — Inbox

| Module | Does |
|---|---|
| `src/git/merge_base.rs` | Merge-base with the upstream, else `HEAD` |
| `src/review/order.rs` | Behaviour rows by lit-check count, then by the name-based caller count, then by path. The header prints that key |
| `src/review/inbox.rs` | Orchestration, cached by the old oid and the new oid |
| `src/engine/review.rs`, `src/ffi/review.rs` | The records the app reads |
| `app/Ride/Review/` | The Symbols segment beside Files |

Groups, in order: behaviour, then light, then equivalent collapsed to counts. Light is doc-only, import-only (`use` / `#include`), and items that are tests. Light counts as needs eyes and is listed last. Equivalent never counts as needs eyes. Over twenty behaviour rows, group by the file's module. A row opens the item.

The cold path is outline, hash, hunk assign, and the two proofs. No compiler. No `git log`. Target on the dev Mac, 200 changed files: under 1 s warm, under 3 s cold. If a real agent branch collapses under 20% into equivalent, the equivalent group shrinks to formatting only.

## Slice C — Marks

| Module | Does |
|---|---|
| `src/follow/mark.rs` | The entry. Kinds: suspect, question, verified, answer, note |
| `src/follow/marks_file.rs` | `.ride/follow/<author>.toml`. Sorted by id. Id is a time prefix plus a short random tail |
| `src/follow/union.rs` | Read every file. The author's slug is `git config user.name` with path separators stripped. Empty: do not write |
| `src/follow/state.rs` | Derived, never stored |

States in this slice: fresh, stale, moved, orphan. Moved follows a mark when exactly one item in the crate has the old shape hash. Otherwise orphan. An orphan stays listed until dropped.

`docs/sessions/follow-format.md` is written with this slice. It is the schema an agent will answer in later.

The inbox header then shows needs eyes, verified, suspect, question, unchecked. Unchecked is needs eyes minus the three marks. Note freshness is not in the count. A verified mark counts when its basis equals the current shape hash, whoever wrote it.

## Slice D — Checks

One file per check under `src/review/checks/`, behind one trait. Each check has a fixture that lights it and one that does not.

| Check | Lit when |
|---|---|
| Public signature | A `pub` item, or an item in a header, changed signature |
| Added or removed | Not part of a proved move |
| Unsafe or FFI | The item's tokens gained or lost `unsafe`, `extern`, a raw pointer, `transmute`, or a C cast |
| Test weakened | In a test item: fewer assertion macros, or `#[ignore]` added, or `should_panic` added |
| New panic path | The count of `unwrap`, `expect`, `panic!`, `unreachable!` rose |

## Slice E — Dossier and since verified

The panel for the item under the caret, with the model off:

- signature, doc, file, line, item id
- callers and callees by name, labelled by name
- the change, its group, its checks
- marks on this item

Author's words is a separate load, not part of opening the inbox: subjects of commits in base..HEAD whose hunks meet the item, newest first, labelled as the author's words. Cached per base and head.

Since verified: a stale mark diffs the item's text at its `commit` against now. Line hunks. Word marks wait for the October diff engine. The reviewer reads the lines that moved, and the rest of the function stays put.

A gutter mark opens this panel.

## Slice F — Trail and hunt

`src/trail/entry.rs`, `src/trail/store.rs`. JSON lines under Application Support, keyed by the repository id. Append only. A test run stores the commit, the failing names, and the messages. A debug stop stores frames and the watches the user had set. Nothing in the trail is committed.

Cite shows a one-line summary and writes it only after the user edits or accepts it. The line is the note. The trail id is not written into the repo.

The hunt list has one shape. From a failing test, the base is the last commit where this Mac's trail saw that test green, labelled as such, else the merge-base. Candidates are the call names inside that test's own body, intersected with behaviour changes since the base. An item changed before that base is absent. From a debug stop, candidates are the frames and the call names inside the stopped function. From a visual note, candidates are the item it is pinned to and the call names inside it. Rank: on the stack, then lit checks, then an open suspect or question.

Done when: a seeded failure lists the changed name the test calls, and leaves out an item whose change is older than last green.

## Slice G — Map, note, evidence, hand-off

Call edges on the map come from the same name index as Call Hierarchy, labelled by name. A self-test on `samples/rust-demo` still finds the two callers of `record`. Badges: needs eyes, suspect, question, evidence, a failing test whose body names an item in the card. A module card shades by its unchecked share.

Generate note uses the context pack already built for Explain. The cache key is the item id and the shape hash. A token edit stales it. A reformat does not. Share note copies the text into the author's follow file.

Dropping an image stores it on the local trail and shows it in the dossier. Share copies it to `.ride/evidence/<shape-prefix>-<n>.png` and writes a suspect or question mark that names the path. An image over 2 MB is refused.

Copy review summary and Copy agent brief put markdown on the clipboard. The brief tells the agent to answer in `.ride/follow/<agent>.toml` with `re` set to the mark id. A file with `agent = true` shows its answers under the question, labelled as that agent's claim. Accept is a human action on the answer. An agent entry never changes a count or a verified state.

## Order

A, then B, then C. That is the first slice: a branch reads as behaviour, formatting and unique moves collapse, and a mark survives `cargo fmt`. D next, because the inbox order is weak without checks. E, F, then G.

The October cards this uses, and does not wait on: the inbox reads `git diff` and does not wait for the edit plan. Since verified starts on line hunks and picks up word marks when the diff engine lands. Debug-a-test stays the debugging card. The hunt is the reading of its result.

## Left unscheduled

The eight holds in §0.1. Also left as v2 already left them: a picker for an arbitrary base, verify-all on a module, a CI file for last green, and any check that an agent's `agent = true` is true.
