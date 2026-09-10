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
        let roomAbove = anchor.screen.maxY - completion.maxY - gap
        let roomBelow = completion.minY - gap - anchor.screen.minY
        let preferAbove = anchor.completionAboveCaret
        let goAbove: Bool
        if (preferAbove ? roomAbove : roomBelow) >= size.height {
            goAbove = preferAbove
        } else if (preferAbove ? roomBelow : roomAbove) >= size.height {
            goAbove = !preferAbove
        } else {
            goAbove = roomAbove >= roomBelow
        }
        let height = min(size.height, max(goAbove ? roomAbove : roomBelow, 0))
        let y = goAbove ? completion.maxY + gap : completion.minY - gap - height
        var frame = NSRect(x: completion.minX, y: y, width: size.width, height: height)
        if frame.maxX > anchor.screen.maxX {
            frame.origin.x = max(anchor.screen.minX, anchor.screen.maxX - size.width)
        }
        return frame
    }
}
