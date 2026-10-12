# Ride — Support plan (2027), v2: the team reads what the agents wrote

| Field | Value |
|---|---|
| Date | 2026-10-11 |
| Status | Proposed. Holds in §0.1 are not to be built. The build order is `plan/roadmap/support-2027-v2-build.md` |
| Sits beside | `plan/roadmap/progress-2026-10.md` (the floor), `plan/roadmap/level-up.md` (the IDE bets) |
| Horizon | A native Mac IDE whose second job is explainability of the workspace and follow-up of the work |
| Presentation | `docs/product/support-2027-v2.html` — one night of agent output and the morning after, as mock screens |

## 0. Review of v1: what this revision changes

v1 has the right shape: engine facts first, the model narrates, judgment is a file, the classical IDE stays. It breaks in four places when it meets a real night of agent output: the hash it pins everything to is too fragile, the inbox has no triage, the shared file will conflict, and the loop ends at the mark instead of going back to whoever writes the fix.

| # | v1 | Problem | v2 |
|---|---|---|---|
| R-1 | Marks and notes pin to a hash of the item text | One `cargo fmt` from the agent stales every verified mark and every note on the branch. The team's work disappears on a whitespace change | **Shape hash**: tree-sitter tokens of the item, whitespace and plain comments dropped (§4.1) |
| R-2 | Every symbol change is a row | A night of agent output is mostly mechanical: formatting, moved items, renames. v1's own story has 6,200 lines and 14 rows, which does not add up | **Equivalence triage**: changes the engine can prove token-equivalent collapse into one group. Only the rest need eyes (§4.2) |
| R-3 | Rows in file order | No answer to "where do I start" | **Review order**: rows sorted by lit checks, then caller count, grouped by module. The sort key is visible (§4.3) |
| R-4 | `symbol = "parse"` | Ambiguous across modules and impls. Lost on a move or rename | **Item id**: qualified path plus kind. A mark follows a move when the shape hash matches (§4.1) |
| R-5 | One shared `.ride/follow.toml` | Every reviewer appends to the same file. Two branches with marks conflict on every merge | **One file per author**: `.ride/follow/<author>.toml`. Ride reads the union (§4.6) |
| R-6 | A changed item shows its mark as stale | The agent pushes again. The reviewer rereads the whole function to find two new lines | Each mark stores the commit it was made at. A stale mark opens **since verified**: only the item's change since that person checked (§6) |
| R-7 | "Test mentions" by name | Misses tests that reach the item through a helper. Hits tests that only name it in a string | **Static reach**: walk callers in the reference index up to `#[test]` functions, depth-limited, labelled static. Name mention stays as the fallback (§4.4) |
| R-8 | Count is changed / verified / suspect / unexplained | "Unexplained" mixes "no note" (needs a model) with "nobody looked". With AI off the count never moves | Count is **needs eyes / verified / suspect / question / unchecked**. Note freshness is its own column (§4.3) |
| R-9 | Verified covers the item text, silently | A verified caller stays trusted after the callee it relies on changed | Verified stays valid and shows **callee changed since** as a hint (§4.6) |
| R-10 | Hunt intersects with changes since the merge-base | The branch carries 55 behaviour changes. The test broke on the last push | Hunt base is the **last commit where the trail saw this test green**, merge-base when unknown. The list is ranked (§5) |
| R-11 | D-7 pins the picture like a mark, §4.4 keeps it in the local trail | Contradiction | Evidence is local by default. **Share** copies the image into `.ride/evidence/` and writes a mark citing it (§4.7) |
| R-12 | A shared mark can point at a local trail entry | The pointer dangles on every other Mac | **Cite** inlines a one-line summary the user edits before it is written. Nothing local is referenced by id (§4.6) |
| R-13 | "Stores the answer on the symbol" | Never says where a note lives, or who sees it | Notes cache locally by (item, shape hash). **Share note** writes it into the author's follow file (§4.5) |
| R-14 | The plan ends at the mark | The suspect list has to reach whoever writes the fix, usually the agent | **Hand-off**: Copy agent brief and Copy review summary, plain markdown. Agents can reply in their own follow file and show labelled as claims (§4.9) |
| R-15 | No view of what the agent said it did | The reviewer cannot compare intent with effect | The dossier lists the commit subjects that touched the item, labelled **author's words** (§4.4) |
| R-16 | Structural checks do not cover agents gaming tests | An agent that loosens an assertion to go green is the cheapest bug to ship | New check: **test weakened** (assertion count dropped, `#[ignore]` or `should_panic` added) (§4.2) |
| R-17 | No sizes, no first slice, no success measure | Hard to schedule against the October floor | Sizes per card, a first slice, measures, risks (§8–§10) |

## 0.1 Holds

Reviewed against the tree on 2026-10-11. The reference index records a call by the bare name and the enclosing item's bare name (`src/refs/record.rs`). It does not record an item id. Diagnostics are a `cargo` or `clang` run of the working tree. The oracle server has diagnostics disabled. These holds follow from that. The build plan does not schedule them.

| # | Held | Why it is not a proof here |
|---|---|---|
| H-1 | Cross-file rename equivalence (§4.2) | "Every reference to `X` moved to `Y`" is false for a common name. Inside the diff it misses callers that still use the old name. Across the index, unrelated calls share the name, so the proof never fires or fires wrong. D-3: a false equivalent is the worst failure. Formatting and a unique move stay |
| H-2 | Static reach to depth 4, and the pill "no test reaches" (§4.2, §4.4, §5) | A walk from `balance` by name gathers every function that calls anything named `balance`. On a real crate that invents tests and misses the real one. `samples/rust-demo` would pass only because its names are unique |
| H-3 | "Callee changed since" (§4.6) | It needs the callee's shape at `commit` and now, for the same item. A name match lights the hint when a different `new` changed, on a mark the team was told was fresh |
| H-4 | The pill "new diagnostic" (§4.2) | Knowing a diagnostic is new means compiling the base revision. That is a second build, and it does not fit the inbox budget. Problems already lists what fails now |
| H-5 | "A comparison literal changed alongside the code it tests" (§4.2) | Alongside is undefined. A test updated to expect the new value lights it every time, so the pill becomes noise. The rest of test-weakened stays: assertion-macro count dropped, `#[ignore]` added, `should_panic` added |
| H-6 | Index-by-literal as a panic path (§4.2) | The grammar cannot see that `slice[i]` panics and `slice.get(i)` does not. Count `unwrap`, `expect`, `panic!`, `unreachable!` only |
| H-7 | `src/follow/migrate.rs` (§7) | v1 never shipped. There is no `.ride/follow.toml` to migrate |
| H-8 | Hunt measure "faulty item in the top three" (§9) | It depends on H-2. The gate that matches the walk we can do is in the build plan |

Narrowed, and still built:

- Rust doc comments count in the shape hash. C and C++ comments all drop. A reworded banner in a header must not stale a mark. C++ has no doctest contract.
- The item id is the file, the chain of enclosing outline names by span, and the kind. Two items that share that chain append the outline signature. It is not a type-checked path.
- The renamed change kind is not produced. A name token change stays a body or signature edit and needs eyes.
- Last green is labelled "on this Mac". Otherwise the base is the merge-base.
- Mark ids are time-prefixed, so sorting the file appends. A random id reshuffles the toml on every write.
- Author comes from `git config user.name`, with path separators stripped. An empty name does not write a file.

## 1. The job

In 2027 the agents write the code. A small team of humans receives large changes, faster than anyone can read line by line, and has to answer four questions:

1. What is this program now?
2. What just changed, and which of it actually changes behaviour?
3. What have we checked, and what is still open?
4. Where is the functional, logical, or visual bug, and who fixes it?

Ride stays the classical IDE it already is: edit, complete, navigate, refactor, build, run, test, debug, git. This plan adds the support layer on top. Three surfaces:

| Surface | Question | What the team looks at |
|---|---|---|
| Workspace transparency | 1, 2 | The map, the dossier, the incoming change read as symbols and triaged |
| Work follow-up | 3 | Marks per author, the count, since-verified diffs, a local trail of tests and stops |
| Hand-off | 4 | One hunt list from a test, a stop, or a picture, and a brief that leaves Ride as markdown |

The change usually arrives from outside Ride: an agent commit, a pulled branch, a dirty tree. Reading that change is the front door. The edit plan from `progress-2026-10.md` P2 stays the path for the human's own fixes.

## 2. What already carries the weight

| Need | Already in the tree |
|---|---|
| Shape of the program | Workspace map (⌘9): crates, modules, items, Cargo edges, sibling `use` edges. Call and type edges are open in `todo/app/workspace-map.md` |
| Who calls whom | Call hierarchy (⌃⌥H) and type hierarchy (⌃H) from the reference index (`src/engine/hierarchy.rs`) |
| Where a name is used | Find Usages (⌥F7), code vision |
| What a selection does | Explain and the context pack (`Engine::ai_context`): focus, enclosing item, referenced definitions, 24k budget |
| Old and new text | `git` CLI runner, `src/git/blob.rs` reads a blob at a revision, `diff_parse.rs` gives hunks with old and new line numbers |
| Grammars | tree-sitter for Rust, C, C++, TOML, Markdown, CMake, Make. Outlines come from the same trees |
| Does it run | Targets, run, tests (`src/engine/test_runner.rs`), Problems, live `cargo` and `clang` checks |
| Why it misbehaves | `lldb-dap`: frames, locals, watches, Rust and libc++ formatters |
| Seeing a page | Markdown and HTML rendered in the editor pane |

## 3. Decisions

| # | Decision | Why |
|---|---|---|
| D-1 | Facts come from the engine. The model only narrates | The map, callers, diff, hash, equivalence and staleness are true with AI off. A note that invents a call edge is a liability on a team |
| D-2 | Everything the team writes pins to an item id and a shape hash | Formatting and comment churn must not erase judgment. A real token change must |
| D-3 | Equivalence is proved or not claimed | A false "equivalent" hides a behaviour change, the worst failure this layer can have. When in doubt the change needs eyes |
| D-4 | Judgment is shared files, one per author. Everything else is local until shared explicitly | Marks are the work product. Debug locals, run logs, notes and screenshots are bulky or sensitive, so Share is a deliberate act |
| D-5 | Incoming git changes are the object of review | Agents will not all apply edits through Ride. `git diff` against a base, read per item, is the view |
| D-6 | One Mac, one developer at a time. The team shares files, not a session | No server, no account. Clone the repo, open it, see the marks |
| D-7 | The classical IDE is not paused and not trimmed | Completion, cheat sheets, rename, intentions, the oracle, the debugger and the October list keep their designs |
| D-8 | Risk is a list of structural checks, shown as themselves | Each check is a visible pill. Order uses them openly. There is no single score that hides them |
| D-9 | Visual bugs are evidence attached to an item | A picture and a sentence, opened beside the code. No pixel diff |
| D-10 | Ride does not run agents. It hands them text | The brief is markdown. The follow files are TOML with a documented schema. Any agent can read them and answer in its own file |
| D-11 | Agent words are claims | Commit subjects and agent replies show labelled with their author. They never set a check, a count or a verified state |

## 4. The objects

### 4.1 Item id and shape hash

An **item** is an outline entry Ride's grammar can see: `fn`, method, `struct`, `enum`, `trait`, `impl`, `const`, `type`, C/C++ function, class, struct, namespace. Its **id** is the file path plus the qualified path plus the kind, for example `src/fold.rs` · `fold::Ledger::balance` · `fn`. Overloads in C++ append the parameter types as the outline prints them.

The **shape hash** is a hash of the item's tree-sitter leaf tokens, in order, with whitespace and non-doc comments dropped. Doc comments count, because they are the item's contract and doctests run them. `cargo fmt`, `clang-format`, and a reworded `//` comment leave the shape hash unchanged. Any token change, including a literal, changes it.

A mark or note whose id no longer exists looks for an item in the same crate with the same shape hash. If exactly one matches, the mark follows it and records the move. Otherwise it becomes an orphan (§4.6).

### 4.2 Symbol change and triage

A working tree, or a branch against a base, is read as symbol changes. For each changed file Ride knows the grammar of, the engine parses the old blob and the new text, takes both outlines, and assigns each hunk to the innermost item whose span contains it. Kinds: body edited, signature edited, added, removed, moved, renamed. Files Ride cannot parse stay as file hunks.

Each change is then triaged into one of three groups:

| Group | Rule | Shown |
|---|---|---|
| Equivalent | Formatting: shape hash equal. Moved: removed and added with the same shape hash, and no other item shares it. Rename across files is H-1 and is not built | Collapsed, with counts per rule. Opens to the list. Never counted as needing eyes |
| Light | Doc-only (only doc comment tokens differ). Import-only (only `use` / `#include` items). Test-only items with no lit checks | Collapsed under needs eyes, listed last. Imports are not equivalent: a new trait in scope changes method resolution |
| Behaviour | Everything else | The review list |

The structural checks (D-8), each a pill:

| Check | Lit when |
|---|---|
| public signature | a `pub` item or a header declaration changed signature |
| added / removed | item added or removed, not as part of a proved move |
| unsafe / FFI | `unsafe`, `extern`, raw pointer, `transmute`, or a C cast touched inside the item |
| no test reaches | Held, H-2. Not a pill |
| new diagnostic | Held, H-4. Not a pill. Problems already shows the working tree |
| test weakened | in a test: assertion macro count dropped, `#[ignore]` or `should_panic` added. The comparison-literal clause is H-5 and is not built |
| new panic path | `unwrap`, `expect`, `panic!`, `unreachable!` count rose. Index-by-literal is H-6 and is not built |

### 4.3 Review inbox

The Changes panel gains a **Symbols** segment beside Files. The base is the merge-base with the upstream, falling back to `HEAD`. A picker offers "since commit…" and "since my last pass" once S1 has been used.

Order inside the behaviour group: number of lit checks, then caller count from the index, then path. The header says so. Rows group by module when there are more than twenty.

The header count:

| Count | Meaning |
|---|---|
| needs eyes | behaviour + light |
| verified | a verified mark on the current shape hash, by anyone |
| suspect | an open suspect mark |
| question | an open question with no accepted answer |
| unchecked | needs eyes minus the three above |

Note freshness (missing, fresh, stale) is a column and a filter, not part of the count. The count moves with AI off.

### 4.4 Dossier

The dossier panel for the item under the caret, all from the engine:

- signature, doc, file, line, item id
- callers and callees from the reference index; the oracle fills names the index could not resolve, labelled
- callers and callees by name, labelled by name. A depth-4 walk to tests is H-2 and is not shown. A name that appears in a test is a mention, labelled as a mention, and it is not a coverage pill
- the symbol change, its triage group and lit checks
- **author's words**: subjects of the commits in base..HEAD whose hunks touch the item, newest first
- the note and its state
- marks, replies, and the since-verified diff when a mark is stale

### 4.5 Note

With a chat model configured, Generate note asks the existing context pack for purpose, behaviour, inputs, outputs, side effects and risks, and caches the answer under Application Support keyed by item id and shape hash. Regenerating is explicit. A note whose shape hash no longer matches stays visible, labelled stale. **Share note** copies it into the author's follow file as a `note` entry, so a teammate opens the same reading without spending a call.

### 4.6 Marks

`.ride/follow/<author>.toml`, committed. The author slug comes from `git config user.name`. Ride never invents one. A file per author means two reviewers never touch the same file.

```toml
[author]
name = "Mira"
agent = false

[[mark]]
id = "m7k2q"
path = "src/fold.rs"
item = "fold::fold_entries"
kind = "fn"
mark = "question"
note = "why does a quiet batch skip the empty check?"
basis = "9e02c1"
commit = "4f2a9c1"
at = "2027-01-14T09:12:00Z"
```

`mark` is one of `suspect`, `question`, `verified`, `answer`, `note`. An `answer` carries `re = "<id>"`. A question is closed when its asker marks an answer accepted (`accepted = true` on the answer) or drops the question. A suspect is closed by dropping it or by a verified mark on a newer shape hash. Entries sort by id so the file diffs cleanly.

States Ride derives, never stores:

| State | When |
|---|---|
| fresh | `basis` equals the current shape hash |
| stale | the item exists and `basis` differs. Still listed. Opens since-verified |
| callee changed | Held, H-3. Not derived |
| moved | followed to a new id by shape hash |
| orphan | no item matches. Listed under Orphans until dropped |

**Cite** attaches evidence from the local trail by writing a one-line summary into `note`, for example `stop at fold.rs:21, quiet = true, n = 3, returns 19`. The user sees and edits the line before it is written.

`.ride/` is excluded from the inbox.

### 4.7 Trail and evidence

Local, per clone, under Application Support, keyed by the repository id. JSON lines, append only:

- test run: target, filter, commit, pass or fail, failing names and their messages
- debug stop: file, line, frames, watches and their values
- visual note: item id, image path, one sentence
- review pass: base, head, the count at that moment

The trail answers "when was this test last green" and "what did I see". It is never written into the repo. **Share** on a visual note copies the image to `.ride/evidence/<shape-hash-prefix>-<n>.png` and writes a `suspect` or `question` mark that names the path.

### 4.8 Map

The workspace map reads the same objects. Call edges come from the reference index, then the oracle where it runs. A card carries badges: needs eyes, suspect, question, evidence, failing test reaching inside. A module card shades by unchecked share. A click on a badge lists the items. Double-click opens the inner graph. The arrow opens the file.

### 4.9 Hand-off

Two commands in the inbox header, both produce markdown on the clipboard:

- **Copy review summary**: base, head, the count, suspects and questions with their notes, failing tests. Meant for a pull request description.
- **Copy agent brief**: the same open items plus file and line, the cited evidence lines, failing test output, and one instruction line: answer in `.ride/follow/<agent>.toml` with `re = "<id>"`. The schema lives in `docs/sessions/follow-format.md` (written with S3-1).

An agent's follow file has `agent = true`. Its answers show under the question labelled as the agent's claim. Only a human accepts one.

## 5. Bug hunt

One list, three starts.

| Start | Base | Candidates |
|---|---|---|
| A failing test | the last commit where this Mac's trail saw this test green, else the merge-base | call names inside that test's own body, intersected with behaviour changes since the base. A depth-4 walk is H-2 |
| A debug stop | the merge-base | frames on the stack, and the call names inside the stopped function, intersected with behaviour changes. Watches go to the trail |
| A visual note | the merge-base | the item it was pinned to, and the call names inside it, intersected with behaviour changes |

Rank: on the stack, then lit checks, then an open suspect or question, then distance from the test. Each row jumps to the item, shows the dossier, and offers Mark suspect, Mark verified, Cite, Explain. Run and debug stay the existing commands.

Logical bugs no test catches are the question and suspect marks made while reading. They stay visible on the map and in the inbox after the chat thread is gone.

## 6. The second push

The agent answers the brief and pushes again. On pull:

- Fresh verified marks still count. Nothing to redo.
- Stale marks list first. **Since verified** diffs the item at the mark's `commit` against now, so the reviewer reads the two new lines, not the function.
- Agent answers show under their questions.
- Notes on changed items turn stale and stay visible.
- The count recomputes. "Since my last pass" in the base picker shows only what moved after the last recorded pass.

## 7. Architecture

Small modules, engine first. Each row is one responsibility.

| Layer | Module | Responsibility |
|---|---|---|
| Engine | `src/review/item_id.rs` | Qualified path and kind from an outline entry |
| | `src/review/shape_hash.rs` | Token stream to hash, comment and whitespace rules per language |
| | `src/review/outline_pair.rs` | Old blob and new text to two outlines |
| | `src/review/hunk_assign.rs` | Hunks to innermost items |
| | `src/review/equivalence.rs` | Formatting, move, rename proofs |
| | `src/review/checks/` | One file per structural check, behind one `Check` trait |
| | `src/review/test_reach.rs` | Not built. H-2 |
| | `src/review/order.rs` | Sort key and grouping |
| | `src/review/inbox.rs` | Orchestration only, cached by (old oid, new oid) |
| | `src/follow/{mark,marks_file,union,state}.rs` | Types, TOML I/O, per-author union, derived states, move following. `migrate` is H-7 and is not built |
| | `src/trail/{entry,store}.rs` | Entries and the JSON-lines store |
| | `src/handoff/{summary,brief}.rs` | Markdown out |
| | `src/git/merge_base.rs`, `src/git/log_range.rs` | Base and per-commit touch for author's words |
| API | `src/engine/review.rs`, `src/ffi/review.rs` | Thin calls and records |
| App | `app/Ride/Review/`, `Dossier/`, `Follow/`, `Hunt/` | Models and views, one per file |

## 8. Phases

Sizes are days, like the October plan. The October floor continues in parallel. Nothing here removes a card from it.

### First slice (about 3 weeks, 15 days): S1-1, S1-2, S1-4, S3-1

Read a branch as symbols, collapse formatting and moves, mark items in per-author files. That alone answers "what changed in behaviour" and "what has anyone checked", and it tests the two riskiest ideas: equivalence and the shape hash.

### S1 — Read a change as symbols

| # | Card | Done when | Days |
|---|---|---|---|
| S1-1 | Symbol diff | A scratch repo with a body edit, signature change, added, removed, and moved item produces those kinds. A non-code file stays a file hunk. Tests in `tests/review.rs` | 4 |
| S1-2 | Shape hash and equivalence | `cargo fmt` over a scratch branch yields zero behaviour rows. A mutation test changes one token in each of 200 items and every one leaves the equivalent group | 4 |
| S1-3 | Structural checks | Each check has a fixture that lights it and one that does not | 3 |
| S1-4 | Inbox segment | Symbols beside Files, three groups, order key in the header, rows jump to the item | 4 |
| S1-5 | Count | Header shows needs eyes / verified / suspect / question / unchecked from marks on current hashes | 1 |

### S2 — The workspace explains itself

| # | Card | Done when | Days |
|---|---|---|---|
| S2-1 | Dossier | Signature, callers, callees, change, checks with AI off | 3 |
| S2-2 | Static test reach | Held, H-2. Not a card | 0 |
| S2-3 | Author's words | Commit subjects per item over base..HEAD, labelled | 2 |
| S2-4 | Call edges on the map | A self-test finds the two callers of `record` on `samples/rust-demo` | 4 |
| S2-5 | Map badges | Needs eyes, suspect, question, evidence, failing test. Refresh recomputes | 2 |
| S2-6 | Note | Generate caches by id and shape hash. A body token edit stales it. Reformatting does not. Share note writes it | 3 |

### S3 — Follow-up the team can share

| # | Card | Done when | Days |
|---|---|---|---|
| S3-1 | Marks files | Per-author TOML round-trips, union read, ids stable, sorted output, `docs/sessions/follow-format.md` written | 3 |
| S3-2 | Gutter and map | A mark paints in the gutter and on the card. Click opens the dossier | 2 |
| S3-3 | Derived states | Fresh, stale, moved, orphan, each with a fixture. Callee-changed is H-3 | 2 |
| S3-4 | Since verified | A stale mark opens the item diff from its `commit` to now | 3 |
| S3-5 | Trail | Test runs and stops append. Cite writes an editable summary line. Nothing from the trail lands in the repo | 3 |

### S4 — The hunt

| # | Card | Done when | Days |
|---|---|---|---|
| S4-1 | Hunt from a failure | Base is last green on this Mac. Candidates are call names in the failing test's body. An item changed before last green is not listed | 3 |
| S4-2 | Hunt from a stop | Record stop on the debug panel opens the same list from its frames | 2 |
| S4-3 | Evidence | Drop an image on an item: local note, dossier, map badge. Share copies it to `.ride/evidence/` with a mark | 3 |

### S5 — Hand-off

| # | Card | Done when | Days |
|---|---|---|---|
| S5-1 | Review summary | Markdown with base, head, count, open items | 1 |
| S5-2 | Agent brief | Markdown with open items, cited evidence, failing output, reply instruction | 2 |
| S5-3 | Agent answers | An `agent = true` file's answers show under questions, labelled, acceptable only by a human | 2 |

Total about 58 days, roughly twelve weeks of one engineer, the first slice included.

### Left on the October plan, used by this one

| October card | How the support layer uses it |
|---|---|
| B-2 diff engine | Word marks in since-verified diffs. S3-4 can start on git's hunks and switch when B-2 lands |
| B-1 edit plan | The human's fixes and any chat Apply travel the same undoable path. The inbox reads git and does not wait for it |
| G-3 history and blame | A dossier row: the last human commit that touched the item. After S2-3 |
| O-4, O-5 inlay hints, semantic tokens | Reading aid inside the buffer. Independent |
| 2.3 debug a test | S4-1 is the reading of that command's result |

## 9. Measures

| Measure | Target |
|---|---|
| False equivalence | Zero on the mutation suite. One failure blocks the release of triage |
| Formatter churn | `cargo fmt` and `clang-format` over a branch stale zero marks and zero notes |
| Inbox latency | 200 changed files: under 1 s warm, under 3 s cold, on the dev Mac |
| Triage share | Recorded on three real agent branches. If under 20% collapse, the equivalent group shrinks to formatting only and the cards are resized |
| Hunt precision | Held as a gate, H-8. The gate that is built: a changed name the failing test itself calls is listed, and an item changed before last green is not |

## 10. Risks

| Risk | Answer |
|---|---|
| Equivalence hides a real change | Conservative rules, the mutation suite, a "show equivalent rows" toggle that is never hidden |
| Outlines fail on macros or C++ templates | The file stays a file hunk, labelled "no outline". Never guessed |
| Follow files become noise in pull requests | `.ride/` excluded from the inbox, entries sorted by id, Drop removes entries instead of flagging them |
| Orphans pile up after big refactors | Orphans section with Drop all, and move following by shape hash |
| A team member does not use Ride | The files are TOML and the brief is markdown. The value leaks out without the app |

## 11. Leave alone

- A second agent runtime, tools loop, or MCP host. Ride hands text to the agent the user already has.
- Embeddings as a way to decide what is related. Callers, callees and the module graph come first.
- A ticket tracker, accounts, or a shared server.
- Pixel diff, screenshot regression, a browser lab.
- Coverage instrumentation. Static reach is labelled static.
- Ghost text and the keystroke path. KD-21 holds.
- Trimming cheat sheets, completion, rename, the oracle or the debugger to make room.

## 12. Open questions

1. Rename proof across files: is "every reference moved" checked against the reference index of the new tree only, or both trees? Both is safer and costs a second index read of the base. Decide in S1-2 with timings.
2. Should a module card offer "verify all" when every behaviour change inside is verified? Convenient and easy to fake. Decide after S3 is used on a real branch.
3. Light group for tests: should test-only items with no lit checks count toward needs eyes? v2 says yes, listed last. Revisit with the triage share data.
4. Agent identity: `agent = true` is self-declared. Enough for a small team. Revisit only if an untrusted agent writes to the repo.
5. Last green comes from this Mac's trail, so it only knows runs this reviewer made. A per-commit CI result (a file CI writes, or `git notes`) would cover the rest. Out of scope until S4-1 has been used.
