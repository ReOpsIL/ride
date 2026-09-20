# AI suggestions in the completion popup

Off by default. Preferences › AI turns it on, picks the provider and the amount of context, and Preferences › Editor › Popups chooses which popups show at all (engine completions, AI suggestions, cheat sheet, signature help, hover documentation).

## Providers

- **Anthropic account** (default): the app signs requests with the OAuth token of the Anthropic CLI profile (`ant auth login`, stored under `~/.config/anthropic/`). No API key is stored by Ride. The AI tab shows the login state, starts `ant auth login` (browser sign-in) and tells the user to install the CLI (`brew install anthropics/tap/ant`) when it is missing. Tokens come from `ant auth print-credentials --access-token`, are cached for five minutes and dropped on a 401.
- **Anthropic API key**: stored in the login keychain (service `dev.ride.Ride`, account `anthropic`).
- **OpenRouter**: API key in the keychain (account `openrouter`), chat completions endpoint.

The model is a picker of presets per provider plus "Custom…" for any model ID. The default is Claude Haiku 4.5 (`claude-haiku-4-5`, `anthropic/claude-haiku-4.5`): completion while typing needs a fast, cheap model, and Haiku answers the completion prompt in about 1.5 s against 4–5 s for Opus 5. OpenRouter also lists Codestral and Qwen3 Coder Flash as cheaper code models. An empty stored model means the default.

## Request

`AIPrompt` builds one system prompt and one user message that holds the edited file with `<|cursor|>` at the caret plus optional extra files. The reply is JSON `{"suggestions":[{"label","text"}]}`; Anthropic requests use structured output with that schema, effort `low`, and `fallbacks: "default"` on Opus 5 / Fable models. OpenRouter replies are parsed leniently (first JSON object in the text). `stop_reason: "refusal"` yields no suggestions.

## Context levels

| Level | Prefix and suffix | Extra files |
|---|---|---|
| Code block | innermost multi-line enclosing range from the engine, else 40 lines around the caret | none |
| Function | innermost outline item containing the caret, else the outermost enclosing range, else 80 lines | none |
| File | whole file | none |
| Directory | whole file | source files in the same directory, 40k characters total |
| Project | whole file | other open buffers, then source files under the workspace root (depth 4), 100k characters total |

Prefix is clipped to the last 12k characters and suffix to the first 4k, on line boundaries; each extra file to its first 6k.

## Flow

`AICompletionSource` waits 400 ms after the last keystroke (or fires at once on ⌃Space), builds the plan on the main thread, loads extra files and sends on a background queue, and drops results that arrive after a newer request. A request already in flight is kept while the user types identifier characters (its suggestions are filtered by the text typed since its caret) and a fresh request follows once it lands; any other edit cancels it. Results are merged into the current completion list as `CompletionItem.ai` rows (shown first, badge "AI"); a suggestion stays visible while what the user keeps typing matches its start, and accepting it replaces the typed part from the request's caret position with the full text. The doc pane shows the whole suggestion. Errors surface once per distinct message as a notice.

## Activity

While any AI request is in flight the status bar shows a spinner with "AI…" (and a sparkles badge whenever AI suggestions are enabled); the AI panel header shows "thinking…". For five seconds after a completion request finishes the badge reports its outcome: "AI: 2 suggestions", "AI: no suggestion", "AI: 2 suggestions (caret moved)" when the popup could not show them, or "AI: failed" (the error itself appears as a notice).

## Ask AI from a comment

Code › Ask AI from Comment… (⌃?) takes the comment under the caret, or the comment run directly above it, as the request text (comment markers stripped, doc-comment slashes included). A sheet shows the editable request, the context level (preset from Preferences › AI, changeable per request) and whether the current selection is included. Sending builds the same context as completion plus the selection inside `<selection>` tags and the request line, asks for a markdown answer (4k tokens, no JSON schema, default effort), and opens the AI panel at the bottom: the question, the answer with text selection, and actions to insert the answer's fenced code blocks at the caret (the whole answer when there are none), copy it, or reopen the sheet to refine the request.
