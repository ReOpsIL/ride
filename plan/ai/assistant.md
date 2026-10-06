# AI assistant: inline completion, Explain, chat

Status: AI-1 to AI-5 implemented 2026-10-06 (engine and RideTests-level logic tested; the app layer needs a build and hands-on check). Builds on the shipped AI completion rows and Ask AI from Comment (`docs/product/ai-complete.md`) and on level-up 2.2 (`plan/roadmap/level-up.md`). KD-21 still holds: off by default, never in the keystroke path, every edit previewed and undoable.

## What the leading tools do (research 2026-10-06)

Sources: VS Code and Copilot docs read first-hand from their GitHub markdown; Zed docs and keymap read first-hand; Cursor, JetBrains and Windsurf from search snippets of their docs (pages blocked by the proxy, re-check before quoting).

| Feature | Best ideas | Where |
|---|---|---|
| Inline completion | Dimmed ghost text, single or multi-line; Tab accepts; ⌘→ accepts a word; Esc or typing past rejects; a manual trigger; per-provider debounce of 0–150 ms; cancel the in-flight request on every keystroke | Copilot `ai-powered-suggestions.md`, VS Code `inlineCompletions/.../commands.ts`, Zed `edit-prediction.md` |
| Popup coexistence | When the language-server popup is open, Tab belongs to the popup; ⌥Tab always takes the AI suggestion; optional "subtle" mode shows the prediction only while ⌥ is held | Zed `edit-prediction.md`, `default-macos.json` |
| Completion context | Prefix and suffix (fill-in-the-middle), snippets from open files near the cursor, recent edits, diagnostics nearby; Cursor adds linter errors and recent edits | GitHub blog on Copilot context; Cursor Tab docs |
| Next edit | A gutter arrow points at the predicted next edit; first Tab jumps, second applies | Copilot NES, Cursor Tab, Windsurf Tab to Jump |
| Explain | Context menu Explain and `/explain`; answer in the chat panel so follow-ups keep the thread; show which elements were attached | VS Code `copilot-smart-actions.md`, JetBrains Explain Code |
| Chat | Side panel; ⌘L adds the selection; implicit current file and selection chips; `#file` / `@file`, `#sym`, diagnostics, codebase search; streaming markdown; code blocks with Copy, Insert, Apply (diff preview); threads with history; read-only Ask mode | VS Code `chat-overview.md`, `copilot-chat-context.md`; Zed `agent-panel.md`; Cursor chat docs |

## Ride's design

The engine owns context, the app owns transport and UI.

| Piece | Where | What |
|---|---|---|
| Context pack | `src/ai/`, `Engine::ai_context(session, start, end, budget)` | Focus (selection or caret line widened to whole lines), the innermost enclosing outline item, and definitions of the symbols the focus references through `quick_definition` (signature and body, capped), skipping anything already shown, within a character budget, with `truncated` flags so prompts say when code was cut |
| Streaming client | `app/Ride/AI/` | Server-sent events for Anthropic (`content_block_delta` / `text_delta`) and OpenRouter (`choices[].delta.content`), cancellable; multi-turn messages; the stable system prompt marked for prompt caching |
| Chat panel | `app/Ride/AI/Chat/` | Right side panel. A thread per conversation; user turns carry context chips (file, selection, symbol); answers stream and render as markdown through the engine renderer with code highlighting; code blocks offer Copy and Insert at Caret; `path:line` links open the location |
| Explain | Code menu, editor context menu | Explain Selection (or the item under the caret) and Explain File start a chat thread with the context pack attached; follow-ups go to the same thread |
| Inline completion | `app/Ride/AI/Inline/` | Ghost text drawn by a TextKit 2 layout fragment at the caret (bottom margin for extra lines, the same mechanism as code-vision labels); shown only when the rest of the caret line is blank; Tab accepts when no popup is open, ⌥Tab always, ⌘→ one word, Esc dismisses; typing that matches the ghost keeps it; debounce 300 ms, manual ⌥\ |

## Sequence

| # | Card | Done when |
|---|---|---|
| AI-1 | Engine context pack | `tests/ai_context.rs` green |
| AI-2 | Streaming client, multi-turn, prompt caching | Answers appear token by token; Esc / Stop cancels |
| AI-3 | Chat panel with threads, chips, markdown, code-block actions | Ask, follow up, insert a code block |
| AI-4 | Explain Selection / File | One command opens a thread with the context attached and streams the explanation |
| AI-5 | Inline ghost-text completion | Ghost text at the caret, Tab / ⌥Tab / ⌘→ / Esc behave as above, the popup keeps Tab while open |
| AI-6 | Later | Next-edit prediction, `@codebase` retrieval over the reference index, Apply with diff preview (needs the edit-plan boundary), persisted threads, ⌘K inline edit |

## Decisions

- **One assistant surface.** Explain and Ask from Comment become chat threads; the bottom AI answer panel goes away.
- **Ghost text replaces the AI rows in the completion popup** as the default; Preferences keeps the popup rows as an option for users who prefer them.
- **No embeddings yet.** Context comes from the engine's definitions and outline; `@codebase` waits for AI-6.
