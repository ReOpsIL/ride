import AppKit

enum CheatSheetPlacement {
    static let gap: CGFloat = 4

    struct Anchor {
        let completion: NSRect?
        let completionAboveCaret: Bool
        let caret: NSRect
        let screen: NSRect
    }

    static func frame(size: NSSize, anchor: Anchor) -> NSRect {
        guard let completion = anchor.completion else {
            return CompletionPlacement.frame(caret: anchor.caret, screen: anchor.screen, size: size)
        }
        let above = completion.maxY + gap
        let below = completion.minY - gap - size.height
        var frame = NSRect(x: completion.minX, y: anchor.completionAboveCaret ? above : below, width: size.width, height: size.height)
        if frame.minY < anchor.screen.minY {
            frame.origin.y = above
        } else if frame.maxY > anchor.screen.maxY {
            frame.origin.y = below
        }
        if frame.maxX > anchor.screen.maxX {
            frame.origin.x = max(anchor.screen.minX, anchor.screen.maxX - size.width)
        }
        return frame
    }
}
