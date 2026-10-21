# Editor line backgrounds

Three things paint a background behind editor text: the caret line, the marked line (the paused debug line, or a jump that opened with `mark: true`) and the matching bracket pair. All three use the TextKit 2 `.backgroundColor` rendering attribute. Each paint replaces the previous value for its range, so whatever is painted last wins.

Before this change each feature added and removed the attribute on its own. Every caret or highlight refresh re-painted the caret line (3% white in the dark theme) on top of the marked line, so the paused line looked almost like the background.

Now `RideTextView.backgrounds` (`BackgroundLayers`) holds the ranges for each layer. `setBackground(_:ranges:)` clears every range it painted before, then paints the layers bottom to top: caret line, marked line, bracket. The colors come from the active theme when painting, so a theme switch (`applyTheme` → `updateCurrentLineHighlight`) recolors every layer.

Adding or removing a rendering attribute does not redraw anything. TextKit 2 draws each line in its own `_NSTextViewportElementView` under the text view, and `needsDisplay` on the text view does not reach those views. So `repaintBackgrounds` collects the full-width line band of every range it removed or painted (`lineBand`, from the text segments) and calls `setNeedsDisplay` for that band on the text view and every view below it. Without this the paused line kept its old drawing until a highlight pass happened to re-lay it out.

Theme keys (`editor` section of each theme JSON, defaults in `EditorColors.load`):

| Key | Dark | Light |
|---|---|---|
| `currentLine` | `#FFFFFF08` | `#0000000A` |
| `markedLine` | `#4C8DFF47` | `#2F6FE033` |
| `bracketMatch` | `#4C8DFF4D` | `#2F6FE04D` |

The self-test step `debug step over` checks that the background drawn on the stopped line is `markedLine`.
