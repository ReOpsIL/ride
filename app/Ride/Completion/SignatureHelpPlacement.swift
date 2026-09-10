import AppKit

enum SignatureHelpPlacement {
    static func frame(size: NSSize, caret: NSRect, screen: NSRect, below: Bool) -> NSRect {
        let above = caret.maxY + Tokens.Space.xxs
        let under = caret.minY - size.height - Tokens.Space.xxs
        var frame = NSRect(x: caret.minX - Tokens.Space.m, y: below ? under : above, width: size.width, height: size.height)
        if frame.maxY > screen.maxY {
            frame.origin.y = under
        }
        if frame.minY < screen.minY {
            frame.origin.y = above
        }
        if frame.maxX > screen.maxX {
            frame.origin.x = max(screen.minX, screen.maxX - size.width)
        }
        return frame
    }
}
