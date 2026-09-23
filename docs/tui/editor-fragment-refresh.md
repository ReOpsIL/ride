# Repainting fold and code-vision fragments

`FoldLayoutDelegate` decides per paragraph whether to return a `HiddenFragment` (folded body), a `FoldHeadFragment` or a `VisionFragment` ("N usages" line above an item, drawn in the fragment's `topMargin`). TextKit 2 caches the fragment it built for a text element; `NSTextLayoutManager.invalidateLayout(for:)` does not make it ask the delegate again, not even followed by `layoutViewport()`.

## Refresh only what changed (`Editing/FragmentRefresh.swift`)

`refreshFragments(in:)` marks just the affected paragraphs as attribute-edited inside a content-storage transaction (which drops their cached fragments so the delegate runs again), lays those paragraphs out at once with `ensureLayout(for:)`, relayouts the viewport and repaints the gutter. Callers say what changed:

| Change | Caller | Paragraphs refreshed |
|---|---|---|
| Usage counts arrive | `UsageCounter.apply` → `refreshVision(from: before)` | lines whose label appeared, disappeared or changed |
| Code vision toggled | `applyCodeVision` → `refreshVision(from: before)` | every line that had or now has a label |
| Fold / unfold / fold all | `FoldController.after` → `refreshFolds(from: before)` | fold ranges present in only one of the two sets |
| Edit overlapping a fold | `EditorCoordinator.shift` | regions `FoldSet.textChanged` released, in post-edit coordinates |

Folds that merely shift with an edit keep their fragments: TextKit 2 fragments follow their text elements.

## Why never invalidate the whole document

The earlier `refreshFolds()` marked the whole store edited and invalidated the document range. TextKit 2 then *estimates* the height of every fragment it has not laid out again, and the estimate knows nothing about vision margins or hidden folds. `NSTextView` sized its frame from that estimate while the fragments in the viewport kept their old positions: after a usage-count change the frame of a 57-line file shrank from 1040 to 1024 pt, the last line fell below the frame (never drawn), the scroll offset was clamped 16 pt up, the scroller vanished and Enter could not scroll past the frame. Laying out the whole prefix instead fixed the height but moved the visible text by thousands of points on large files whose prefix had been estimated.

Invariant: no path invalidates layout for more than the paragraphs whose presentation changed, and every invalidated paragraph is laid out again before the viewport is.

## Vision lines are computed once per change

The delegate asks `visionLine(at:)` for every paragraph it lays out. `VisionIndex` caches the line → label map keyed by the document, the view's text generation and length, and `BufferDocument.visionInputs` (bumped when `outline` or `visionCounts` change), and builds it with one `Utf16Map` instead of scanning the text per outline row per paragraph.

## Typed edits keep the caret visible

`smartNewline`, closing-brace dedent, bracket pairing and pair delete change the text programmatically, which skips `NSTextView`'s own scroll-to-caret. They end in `placeTypedCaret`, which selects and scrolls.

`HighlightApply.apply` does not call `invalidateLayout(for:)`: its attribute edits inside `beginEditing`/`endEditing` already reach TextKit 2 through the content storage.

The gutter draws its line numbers from the laid-out fragments, so it has to be repainted in the same step; `refreshFragments(in:)` marks it dirty. `textLineFragments.first.typographicBounds` is already relative to the fragment frame including the label's top margin.

Self-test `type at end` types newlines and code at the end of a file with the Problems panel open, checks after every viewport layout (through `ViewportWatch`) that the laid-out fragments reach the end of the visible text, and that the caret never sits below the visible rect.
