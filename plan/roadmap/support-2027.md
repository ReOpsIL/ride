# Ride — Support plan (2027): the team reads what the agents wrote

| Field | Value |
|---|---|
| Date | 2026-10-11 |
| Status | Proposed |
| Sits beside | `plan/roadmap/progress-2026-10.md` (the floor), `plan/roadmap/level-up.md` (the IDE bets) |
| Horizon | A native Mac IDE whose second job is explainability of the workspace and follow-up of the work |
| Presentation | `docs/product/support-2027.html` — one morning on an agent branch, told as mock screens |

## 1. The job

In 2027 the agents write the code. A small team of humans receives large changes, faster than anyone can read line by line, and has to answer three questions:

1. What is this program now?
2. What just changed, and what of it have we actually checked?
3. Where is the functional, logical, or visual bug?

Ride stays the classical IDE it already is: edit, complete, navigate, refactor, build, run, test, debug, git. That loop is the instrument panel. This plan adds the support layer on top of it. The layer is two surfaces.

| Surface | Question it answers | What the team looks at |
|---|---|---|
| Workspace transparency | What is this, and what just happened to it? | The map, a symbol dossier, a symbol-level reading of the incoming diff |
| Work follow-up | What have we checked, and what is still open? | Marks on symbols, a verification count, a local trail of tests and debug stops |

The change usually arrives from outside Ride: an agent commit, a pulled branch, a dirty tree. Reading that change is the front door. Applying an edit from the chat panel stays a later, smaller path.

## 2. What already carries the weight

| Need | Already in the tree |
|---|---|
| Shape of the program | Workspace map (⌘9): crates, modules, items, Cargo edges, sibling `use` edges. Call and type edges are the open follow-up in `todo/app/workspace-map.md` |
| Who calls whom | Call hierarchy (⌃⌥H) and type hierarchy (⌃H) from the reference index |
| Where a name is used | Find Usages (⌥F7), code vision |
| What a selection does | Explain and the context pack (`Engine::ai_context`): focus, enclosing item, referenced definitions, 24k budget |
| What changed | Changes panel, unified diff per file, tree badges. Hunks have old and new line numbers. No symbol grouping, no blame, no gutter marks |
| Does it run | Targets, run, tests, Problems, live `cargo` and `clang` checks |
| Why it misbehaves at runtime | `lldb-dap`: frames, locals, watches, Rust and libc++ formatters |
| Seeing a page | Markdown and HTML rendered in the editor pane |

Missing, and named here because the support layer needs them: a diff read per symbol, an explanation that survives the chat thread and goes stale, a shared mark the next person can see, a trail of what was run and where the debugger stopped.

## 3. Decisions

| # | Decision | Why |
|---|---|---|
| D-1 | Facts come from the engine. The model only narrates | The map, the callers, the diff, the hash, and the staleness are true with AI off. A prose explanation that invents a call edge is a liability on a team |
| D-2 | An explanation is pinned to a symbol and stores the hash it was written against | A fresh-looking note about yesterday's function is worse than no note. Hash mismatch shows Stale |
| D-3 | The team's judgment is a file in the repo. The session trail stays local | Suspect, verified, and question marks are the work product the next person needs. Debug locals and run logs are bulky and often sensitive, so they stay in Application Support |
| D-4 | Incoming git changes are the object of review | The agents will not all apply edits through Ride. `git diff` against a base, grouped by symbol, is the view. The edit plan from `progress-2026-10.md` P2 stays the path for the human's own fixes |
| D-5 | One Mac, one developer at a time. The team shares files, not a session | No multiplayer server, no account. Clone the repo, open it, see the marks |
| D-6 | The classical IDE is not paused and not trimmed | Completion, cheat sheets, rename, intentions, the oracle, the debugger, and the October correctness list keep their designs. This plan adds views that jump back into them |
| D-7 | Visual bugs are evidence attached to a symbol | A screenshot and a sentence, pinned like a mark, opened beside the code. Markdown and HTML keep the preview they have. Ride does not become a pixel-diff lab |
| D-8 | Risk is a handful of structural checks, shown as themselves | Public signature changed, item added or removed, `unsafe` / `extern` / raw pointer touched, no test names the symbol, a new diagnostic. Each check is visible. There is no single "risk score" that hides them |

## 4. The objects

### 4.1 Symbol change

A working tree (or a branch versus a base commit) is read as a set of symbol changes, not as a list of files.

For each changed file Ride knows the grammar of, the engine parses the old blob and the new text, takes the outline of both, and assigns each diff hunk to the innermost item whose span contains it. A change is one of: body edited, signature edited, item added, item removed, item moved. Files Ride cannot parse stay as file-level hunks, the way the Changes panel shows them today.

Each symbol change carries the structural checks from D-8, the callers the reference index already knows, and the tests whose names or bodies mention the symbol. That mention test is a hint, shown as a hint.

### 4.2 Dossier

Code › Explain grows a durable result. The dossier panel for the symbol under the caret shows, with the model switched off:

- signature, doc, file, line
- callers and callees
- the symbol change that touches it, if any
- the pinned note and its state: missing, fresh, stale
- marks (section 4.3)

With a chat model configured, Generate note asks the existing context pack for purpose, step-by-step behaviour, inputs, outputs, side effects, and risks, and stores the answer on the symbol together with the item hash. Regenerating is explicit. A stale note stays visible and is labelled stale.

### 4.3 Marks

`.ride/follow.toml` at the repository root, committed by the team:

```toml
[[mark]]
path = "src/parse.rs"
symbol = "parse"
kind = "suspect"   # suspect | verified | question
note = "rejects an empty header the tests never send"
basis = "<hash of the item text>"
author = "dov"
at = "2027-01-14T09-12-00Z"
```

The hash is the engine's hash of the outline item's text. When the current item differs, the mark renders stale and stays in the follow-up list until someone renews or drops it. A question is an open thread of one note. A suspect is a bug candidate. Verified means a person checked this item against this text.

The status line of a review shows the count that matters: changed symbols, how many are verified on the current hash, how many are suspects, how many have no fresh note.

### 4.4 Trail

Local, per clone, under Application Support, keyed by the repository id git reports. Entries append:

- a test run: target, filter, pass or fail, the failing test names
- a debug stop: file, line, frame names, the watches the user had set
- a visual note: symbol, image path, one sentence
- a review pass: the base commit and the verification count at the moment someone records it

The trail is the memory of the hunt. It is not the shared judgment. A mark can point at a trail entry.

### 4.5 Map badges

The workspace map reads the same objects. A card shows a small set of badges: changed, suspect, question, no fresh note on a changed public item, a failing test that mentions a symbol inside. Double-click still opens the inner graph. The card arrow still opens the file. Badges are counts, and a click on a badge lists the symbols.

Call edges join the map here. First from the reference index Ride already builds for hierarchy. Where the oracle is running, its call hierarchy fills names the index could not resolve. A folder with no recognizable structure stays a folder. The chat model is not asked to invent the graph.

## 5. Bug hunt

A hunt starts from one of three places. All three produce the same suspect list.

| Start | Suspect list |
|---|---|
| A failing test | Symbols the test mentions, plus the callees of those symbols, intersected with symbol changes since the base |
| A debug stop | The frames on the stack, intersected with symbol changes, with the stop's watches kept on the trail entry |
| A visual note | The symbol it was pinned to, its callers, and any symbol change among them |

The list opens beside the editor. Each row jumps to the symbol, shows its dossier, and offers Mark suspect, Mark verified, and Explain. Run and debug of that test stay the existing commands.

Logical bugs that no test catches are the question and suspect marks made while reading. The map and the review inbox are where those stay visible after the chat thread is gone.

## 6. Phases

The October floor continues in parallel: ship, the correctness debts, then the edit plan for the human's own multi-file edits. Nothing below deletes a card from that plan. Cards here are the support layer.

### S1 — Read a change as symbols

| # | Card | Done when |
|---|---|---|
| S1-1 | Symbol diff | A scratch repo with an edited function, a signature change, an added item, and a deleted item produces those four kinds. A non-code file stays a file hunk. Tests in `tests/` |
| S1-2 | Review inbox | The Changes panel gains a Symbols segment. Rows are symbol changes against the merge-base of the upstream, falling back to `HEAD`. Structural checks are columns, each on or off |
| S1-3 | Verification count | The segment header shows changed / verified / suspect / unexplained, from marks on the current hashes |

### S2 — The workspace explains itself

| # | Card | Done when |
|---|---|---|
| S2-1 | Call edges on the map | Opening a crate shows edges the reference index can prove. A self-test on `samples/rust-demo` finds the two callers of `record` |
| S2-2 | Map badges | A changed file badges its module card. A suspect mark badges it. Refresh recomputes |
| S2-3 | Dossier | The panel shows signature, callers, callees, and the symbol change with AI off |
| S2-4 | Pinned note | Generate stores the note and the item hash. Editing the body turns the note stale. The note is still shown |

### S3 — Follow-up the team can share

| # | Card | Done when |
|---|---|---|
| S3-1 | Marks file | `.ride/follow.toml` round-trips. A stale basis stays listed. Author and time are recorded. The file is plain toml a human can diff |
| S3-2 | Gutter and map | A mark paints in the gutter of the item and on the map card. Clicking it opens the dossier |
| S3-3 | Trail | A test run and a debug stop append a local entry. A mark can cite the latest entry for its symbol. Nothing from the trail is written into the repo |

### S4 — The hunt

| # | Card | Done when |
|---|---|---|
| S4-1 | Hunt from a failure | Rerun Failed on a red test opens the suspect list defined in section 5 |
| S4-2 | Hunt from a stop | A button on the debug panel records the stop and opens the same list from its frames |
| S4-3 | Visual note | Dropping an image on a symbol stores the path and a sentence, shows it in the dossier, and badges the map |

### Left on the October plan, used by this one

| October card | How the support layer uses it |
|---|---|
| P2 edit plan and diff view | The human's fixes, and any chat Apply, travel the same undoable path. The review inbox reads git and does not wait for it |
| G-3 history and blame | A dossier row: the last commit that touched the item. After S1, not before |
| P4 Apply | A chat code block can still become an edit plan. It is not the front door |
| O-4, O-5 inlay and semantic tokens | Reading aid inside the buffer. Independent of S1–S4 |
| 2.3 debug a test | S4-1 is the support view of that command. Building the gutter action is still the debugging card |

## 7. Leave alone

- A second agent runtime, tools loop, or MCP host. The user already has an agent. Ride receives its output.
- Embeddings as a way to decide what is related. Callers, callees, and the module graph come first.
- A ticket tracker, accounts, or a shared server.
- Pixel diff, screenshot regression, a browser lab.
- Ghost text and the keystroke path. KD-21 holds: the model stays off the keystroke path.
- Trimming cheat sheets, completion, rename, the oracle, or the debugger to make room.

## 8. Open questions

1. Base of the review. Merge-base of the upstream is the default in S1-2. Some teams will want "since this commit" or "since the last recorded review pass." Worth a picker once S1 is in use, not before.
2. Where `.ride/follow.toml` lives in a multi-project folder. One file at the git root covers every project in the clone. Revisit only if two teams share a repo and need separate mark files.
3. Whether a verified mark on a module can be offered when every changed symbol inside it is verified. Convenient, and easy to fake by accident. Decide after S3 has been used on a real branch.
