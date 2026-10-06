# AI chat and Explain

A side panel (View › AI Chat, ⌘8) holds conversations with the chat model. Explain, Add Selection to Chat and Ask AI from Comment all feed it. Plan and research: `plan/ai/assistant.md`.

## Context

`Engine::ai_context(session, start, end, budget)` (`src/ai/`, `src/engine/ai_context.rs`) builds the pack the app attaches:

| Part | What |
|---|---|
| Focus | The selection widened to whole lines. With no selection, Explain and the Selection chip use the innermost outline item at the caret, else the caret line |
| Enclosing | The innermost outline item that strictly contains the focus |
| Definitions | For each distinct symbol the focus references (the reference extractor, `#include`s skipped), the first `quick_definition` hit that is not already inside the focus or enclosing item; up to 16 |
| Budget | 24,000 characters shared in that order, cut on whole lines; a cut snippet carries `truncated`, which the prompt passes on so the model says what it could not see |

The file chip sends the buffer text up to 60,000 characters. Paths are workspace-relative.

## Requests

`AIStreamClient` streams server-sent events: Anthropic `content_block_delta` text deltas (a `refusal` stop reason is shown as a note; `fallbacks: "default"` on models that support it) and OpenRouter `choices[].delta.content`. Each user turn is sent as its `<context kind path line>` blocks followed by the question; earlier turns are replayed unchanged so the conversation prefix stays cacheable (`cache_control` on the request). Failed and stopped answers are left out of the history, and consecutive user turns merge. The chat model is set in Preferences › AI › Chat and Explain (default Claude Opus 5.5; the completion model stays separate and fast).

## Panel

The transcript is one web view: user turns show their chips (links to the code), answers render through the engine's markdown renderer with syntax-coloured code. Updates arrive at most every 50 ms; only changed messages are re-rendered. Code blocks get Copy and Insert (inserts over the selection of the focused editor). `path:line` mentions become links that open the file at that line. ↩ sends, ⇧↩ adds a line, Stop cancels and keeps what arrived. Threads live in memory for the session; the history menu switches and deletes them.

## Explain

Code › Explain (⌃⌘E) and Explain File start a new thread with the pack (or the file) and a fixed request: purpose, step-by-step behaviour, inputs, outputs, side effects and risks for a selection; role, main items and pitfalls for a file. Follow-ups continue the same thread.
