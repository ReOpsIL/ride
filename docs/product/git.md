# Git

Ride shows what changed, commits, pushes, pulls and switches or creates branches without leaving the window. Everything goes through the `git` command line found on the tool path (`toolchain::tool("git")`); there is no libgit2 and no hosting-service client.

## Layers

| Layer | Where | Responsibility |
|---|---|---|
| CLI runner | `src/git/cli.rs` | `Git::at(dir)` runs `git -C <dir>` with `core.quotepath=off`, `color.ui=false`, `GIT_TERMINAL_PROMPT=0` (never waits for a password), `GIT_OPTIONAL_LOCKS=0` (status never rewrites the index, so the file watcher cannot loop) and `LC_ALL=C`. A non-zero exit becomes `EngineError::Git` carrying git's own stdout and stderr. |
| Repository | `src/git/repo.rs` | `open` resolves `rev-parse --show-toplevel`, so a workspace inside a larger checkout works. Every operation runs at the top level and every path is relative to it. `status` returns `None` outside a repository. |
| Parsers | `status_parse.rs`, `diff_parse.rs`, `branch.rs`, `line_spans.rs` | `status --porcelain=v2 --branch -z --untracked-files=all` into `GitRepoStatus`; one file's unified diff into hunks with old and new line numbers; `for-each-ref` into local and remote branches (symbolic `origin/HEAD` dropped). |
| Operations | `stage.rs`, `commit.rs`, `branch.rs`, `branch_name.rs`, `remote.rs`, `diff.rs`, `diff_plan.rs`, `blob.rs` | See below. |
| Engine API | `src/engine/git.rs` (reads), `src/engine/git_ops.rs` (writes) | `git_status`, `git_diff`, `git_branches`, `git_last_message`, `git_stage`, `git_unstage`, `git_discard`, `git_commit`, `git_create_branch`, `git_checkout`, `git_push`, `git_pull`, `git_fetch`. Records live in `src/ffi/git.rs`. |
| App state | `app/Ride/Git/GitStatusService.swift`, `GitChangesModel.swift` | The status service owns the latest `GitRepoStatus` and the tree marks; the changes model owns the selection, the diff, the commit message, the amend flag, the branch list and the busy label. |
| App orchestration | `AppState+Git.swift`, `AppState+GitOps.swift` | Every write goes through `gitRun`: one operation at a time, off the main thread, busy label in the panel header, status refresh afterwards, failures as a notice with git's message. |
| App views | `GitPanel`, `GitChangeList`, `GitChangeRow`, `GitCommitBox`, `GitDiffView` (AppKit: `GitDiffScrollView`, `GitDiffTextView`, `GitDiffGutter`, `GitDiffDocument`), `GitBranchMenu`, `GitCommands` | The Changes panel, the Git menu, tree marks (`TreeRow`) and the branch segment in the status bar. |

## Behaviour

- **Change kinds.** Each file carries an optional staged kind and an optional unstaged kind (`Modified`, `TypeChanged`, `Added`, `Deleted`, `Renamed`, `Copied`, `Untracked`, `Conflicted`). A file can sit in both sections of the panel. The tree and the panel colour a file by its unstaged kind, else its staged kind.
- **Diffs.** `git_diff(change, side)` picks the command from the side: unstaged is `diff -- path`, staged is `diff --cached -M -- [orig] path`, untracked is `diff --no-index /dev/null path`, conflicted is `diff HEAD -- path`.
- **Diff highlighting.** `DiffPlan` names both versions a diff compares (unstaged: index → work tree, staged: HEAD → index, untracked: nothing → work tree, conflicted: HEAD → work tree). For a file whose language Ride knows (`Lang::recognized`, the editor's grammars), the engine highlights each whole version with tree-sitter and cuts the spans per line, so a removed line is coloured from the old file and an added or context line from the new one, and multi-line comments and strings stay right. `GitDiffLine.spans` carry UTF-8 offsets into the line text. Unknown extensions get no spans.
- **Diff view.** An `NSTextView` in an `NSScrollView` (no wrapping, both scrollbars, selectable and copyable). Added and removed lines get a full-width tint drawn behind the text, hunk headers a light one. Old and new line numbers sit in a vertical ruler that stays put while the text scrolls sideways. Font size follows the editor preference and colours follow the theme.
- **Stage and unstage.** Stage is `add --all -- paths` (deletions included). Unstage is `restore --staged`, or `rm --cached` before the first commit.
- **Discard** acts on the unstaged side only: tracked files are restored from the index, untracked files are deleted with `clean`. The app asks first and says when files will be deleted.
- **Commit.** The message is fed on stdin (`commit --file=-`). With nothing staged the button reads Commit All and stages everything first. Amend with an empty message keeps the previous one (`--no-edit`); ticking Amend on an empty box loads the last message.
- **Push** uses the upstream when one is set, else `push --set-upstream <origin or first remote> HEAD`. With no remote it fails with a message saying so. **Pull** is `--ff-only`, so a diverged branch is reported, never merged or rebased silently. **Fetch** prunes.
- **Branches.** Names are validated before git sees them (`BranchName`: no leading `-`, then `check-ref-format --branch`). New Branch creates and switches (`switch --create`). Picking a remote branch runs `switch --track`, which creates the local tracking branch.
- **Refresh.** Status reloads on workspace open, after every operation, when the file watcher sees a source change, and when `.git/HEAD`, `refs`, `packed-refs` or `index` change, so staging from a terminal shows up too.

## Keys

`⌘0` toggles the Changes panel, `⌘K` opens it with the commit message focused, `⇧⌘K` pushes. Pull, Fetch, New Branch… and Refresh Status are in the Git menu without keys.

## Tests

`tests/git.rs` drives the engine against scratch repositories (status from a subdirectory, staging before the first commit, all diff sides, commit and amend, discard, branches, push to a bare remote and pull). Parser unit tests sit next to the parsers. `app/RideTests/GitPathMapTests.swift` covers the repository-to-workspace path mapping.
