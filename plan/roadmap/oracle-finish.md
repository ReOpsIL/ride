# Finishing the semantic oracle (release 2.1 remainder)

Completion from rust-analyzer and clangd shipped on 2026-09-28 (`docs/product/semantic-oracle.md`). This plan covers the rest of release 2.1 in `level-up.md`, in the order that gives the most per day.

## Principles kept

- Typing never waits on a server. Explicit actions (⌘-click, F12, ⌃J, ⌥Space, hover) may wait a bounded time off the main thread and off the per-document session queue, then fall back to Ride's own answer.
- Ride's heuristics stay as the fallback when a server is off, missing, loading or silent.
- One shared fleet of server processes, one per (server, project root), used by the completion worker and by explicit requests alike.

## Steps

| # | Step | What changes for the user | Notes |
|---|---|---|---|
| O-1 ✓ | Shared fleet | Nothing visible | Sidecars move from the worker into a thread-safe `Fleet`; document sync is locked per sidecar; explicit requests use a ready sidecar directly, or ask the worker to start one and fall back meanwhile |
| O-2 ✓ | Definitions from the servers | Go to Definition, Quick Definition and Quick Documentation resolve method chains, trait methods, overloads and templates | `find_definitions` asks `textDocument/definition` first (1.5 s cap) and builds hits from the returned locations; hover and ⌃J move to the workspace lane |
| O-3 ✓ (Type Info) | Type info and hover types | ⌃⇧P and the hover card show the real type of any expression or binding | `textDocument/hover`, first code block of the answer |
| O-4 | Inlay hints | Types after `let`/`auto` bindings and parameter names in calls, drawn in the editor | `textDocument/inlayHint` for the visible range, refreshed after edits settle; needs editor drawing work |
| O-5 | Semantic highlighting | Locals, parameters, fields, types and macros coloured from the server | `textDocument/semanticTokens/range` merged over tree-sitter spans for the visible range |
| O-6 | Live type errors | Server diagnostics while typing | Low value: Ride already runs cargo and clang checks while typing; do last, if at all |

The deferred refactorings (Extract Function, Change Signature, trait and base-class generators) come after O-2 and O-3, because they need resolved types and definitions.
