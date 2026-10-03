import AppKit

enum CompletionPlacement {
    static func caretRect(in view: NSTextView) -> NSRect {
        var actual = NSRange()
        let caret = view.selectedRange()
        return view.firstRect(forCharacterRange: NSRange(location: caret.location, length: 0), actualRange: &actual)
    }

    static func screen(for view: NSTextView) -> NSRect {
        view.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
    }

    static func frame(for view: NSTextView, size: NSSize) -> NSRect {
        frame(caret: caretRect(in: view), screen: screen(for: view), size: size)
    }

    static let clearLines: CGFloat = 2

    static func gap(caret rect: NSRect) -> CGFloat {
        rect.height * clearLines
    }

    static func frame(caret rect: NSRect, screen: NSRect, size: NSSize) -> NSRect {
        let clear = gap(caret: rect)
        let lane = PopupLane.pick(
            .below(from: rect.minY - clear, screen: screen),
            .above(from: rect.maxY + clear, screen: screen),
            height: size.height
        )
        return lane.frame(x: rect.minX - Tokens.Space.m, size: size, screen: screen)
    }

    static func caretVisible(in view: NSTextView) -> Bool {
        guard let scroll = view.enclosingScrollView, let window = view.window else {
            return true
        }
        let visible = scroll.contentView.convert(scroll.documentVisibleRect, to: nil)
        return window.convertToScreen(visible).intersects(caretRect(in: view))
    }
}
