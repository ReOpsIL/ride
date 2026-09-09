import AppKit

enum CompletionPlacement {
    static func caretRect(in view: NSTextView) -> NSRect {
        var actual = NSRange()
        let caret = view.selectedRange()
        return view.firstRect(forCharacterRange: NSRange(location: caret.location, length: 0), actualRange: &actual)
    }

    static func frame(for view: NSTextView, size: NSSize) -> NSRect {
        let rect = caretRect(in: view)
        let screen = view.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var frame = NSRect(x: rect.minX - Tokens.Space.m, y: rect.minY - size.height - 2, width: size.width, height: size.height)
        if frame.minY < screen.minY {
            frame.origin.y = rect.maxY + 2
        }
        if frame.maxX > screen.maxX {
            frame.origin.x = max(screen.minX, screen.maxX - size.width)
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
