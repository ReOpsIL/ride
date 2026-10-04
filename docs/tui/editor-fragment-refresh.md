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

## Style writers settle what they invalidate (`Editor/RideTextView+Styles.swift`)

Syntax colours (`HighlightApply`) and underlines (`Underlines`) are text-storage attributes. Any attribute write, even one that sets the value already there, makes TextKit 2 drop the layout of every paragraph in the storage's `editedRange`, and inside one `beginEditing`/`endEditing` that range is the union of all writes. Two writes far apart (a warning underline near the top, a parse error at the caret) therefore invalidate everything between them. Paragraphs above the viewport fall back to estimated heights that ignore vision margins, hidden folds and soft wrap, and the viewport's first fragment lands below the visible top: a blank band that flickers while typing and fills in on scroll.

Both writers go through `editStyles`, which:

1. records the fragment at the visible top and its distance from it,
2. runs the writes in one transaction and reads the storage's `editedRange`,
3. lays out again the part of that range above the anchor (`ensureLayout(for:)`), so nothing above the viewport stays estimated,
4. scrolls so the anchor fragment keeps its distance from the visible top. If the prefix had only been estimated before (a jump into a large file), the exact layout changes its height, and the text on screen stays put instead of moving.

`Underlines.apply` also writes only what differs: it clears old ranges that are no longer wanted and applies a mark only when the storage does not already carry that style and colour over the whole range (`UnderlineMark.isApplied`). Unchanged diagnostics no longer widen the edited range on every keystroke.

Self-test `type in scrolled labelled file` opens `util.rs` with usage labels and soft wrap on, appends a trait impl with a long method, scrolls to its end and types `(1, (2, x`, which turns the whole file into a parse error. It checks every viewport layout through `ViewportWatch` and that the top visible line does not move.

## Vision lines are computed once per change

The delegate asks `visionLine(at:)` for every paragraph it lays out. `VisionIndex` caches the line → label map keyed by the document, the view's text generation and length, and `BufferDocument.visionInputs` (bumped when `outline` or `visionCounts` change), and builds it with one `Utf16Map` instead of scanning the text per outline row per paragraph.

## Typed edits keep the caret visible

`smartNewline`, closing-brace dedent, bracket pairing and pair delete change the text programmatically, which skips `NSTextView`'s own scroll-to-caret. They end in `placeTypedCaret`, which selects and scrolls.

`HighlightApply.apply` does not call `invalidateLayout(for:)`: its attribute edits inside `beginEditing`/`endEditing` already reach TextKit 2 through the content storage.

The gutter draws its line numbers from the laid-out fragments, so it has to be repainted in the same step; `refreshFragments(in:)` marks it dirty. `textLineFragments.first.typographicBounds` is already relative to the fragment frame including the label's top margin.

Self-test `type at end` types newlines and code at the end of a file with the Problems panel open, checks after every viewport layout (through `ViewportWatch`) that the laid-out fragments reach the end of the visible text, and that the caret never sits below the visible rect.
