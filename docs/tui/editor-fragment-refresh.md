# Repainting fold and code-vision fragments

`RideTextView.refreshFolds()` is the single point that makes the editor show a change that is not a text edit: a fold opening or closing, and the "N usages" code-vision lines arriving from `UsageCounter`.

Both are drawn by `FoldLayoutDelegate`, which decides per paragraph whether to return a `HiddenFragment`, a `FoldHeadFragment` or a `VisionFragment`. TextKit 2 caches the fragment it already built for a text element, and `NSTextLayoutManager.invalidateLayout(for:)` does not make it ask the delegate again — not even followed by `layoutViewport()`. Until the buffer was edited, the old fragments stayed on screen, so code-vision labels never appeared after their counts loaded and a fold only took effect on the next keystroke.

`refreshFolds()` therefore marks the whole backing store as attribute-edited inside a content-storage transaction before invalidating. That drops the cached fragments, the delegate runs again, and the viewport relayouts.

The gutter draws its line numbers from the laid-out fragments, so it has to be repainted in the same step or it keeps numbers at the old heights and they drift one row per vision label. `refreshFolds()` marks the gutter dirty itself; callers do not repeat it.

The gutter needs no offset of its own for a vision line: `textLineFragments.first.typographicBounds` is already relative to the fragment frame including the label's top margin.
