import AppKit

enum CompletionPlacement {
    static let width: CGFloat = 520
    static let rowHeight: CGFloat = 24

    static func caretRect(in view: NSTextView) -> NSRect {
        var actual = NSRange()
        let caret = view.selectedRange()
        return view.firstRect(forCharacterRange: NSRange(location: caret.location, length: 0), actualRange: &actual)
    }

    static func frame(for view: NSTextView, rows: Int) -> NSRect {
        let height = min(CGFloat(rows) * rowHeight + 8, 280)
        let rect = caretRect(in: view)
        let screen = view.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var frame = NSRect(x: rect.minX, y: rect.minY - height - 2, width: width, height: height)
        if frame.minY < screen.minY {
            frame.origin.y = rect.maxY + 2
        }
        if frame.maxX > screen.maxX {
            frame.origin.x = max(screen.minX, screen.maxX - width)
        }
        return frame
    }

    static func caretVisible(in view: NSTextView) -> Bool {
        guard let scroll = view.enclosingScrollView, let window = view.window else {
            return true
        }
        let visible = scroll.contentView.convert(scroll.documentVisibleRect, to: nil)
        return window.convertToScreen(visible).intersects(caretRect(in: view))
    }
}
