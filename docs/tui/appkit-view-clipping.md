# AppKit views draw only inside their bounds

Since macOS 14 `NSView.clipsToBounds` defaults to `false`. A non-clipping view gets a backing content layer the size of its nearest clipping ancestor, and `draw(_:)` receives dirty rects that reach that far. Any view that paints a background by filling the dirty rect then paints over its siblings and over SwiftUI content laid out around it.

The editor find bar showed this: `PaneColumn` places `FindBar` above `EditorPane` in a `VStack`, so the bar took its 36 pt and every control was laid out at full opacity, yet the strip showed the editor background. `GutterView` filled `dirtyRect` with `editor.background`, its content layer spanned the whole split item (1207 × 787 instead of 60 × 751), and the fill covered the bar. The scroll view sibling hid the rest.

Invariant: a view that paints its own background clips to its bounds. `GutterView` sets `clipsToBounds = true` in its initializer and fills `bounds ∩ dirtyRect`.

To diagnose an invisible SwiftUI region next to an AppKit view, walk the window's layer tree from the platform host (`layer.convert(bounds, to: rootLayer)`) rather than the view tree: view frames were all correct here, and only the layer dump exposed the oversized content layer. The `findbar` demo scene captures the bar so `scripts/screenshots.sh findbar` shows the state.
