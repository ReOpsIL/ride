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
        let clear = CompletionPlacement.gap(caret: anchor.caret)
        let stacked = anchor.completionAboveCaret
        let above = PopupLane.above(from: stacked ? completion.maxY + gap : anchor.caret.maxY + clear, screen: anchor.screen)
        let below = PopupLane.below(from: stacked ? anchor.caret.minY - clear : completion.minY - gap, screen: anchor.screen)
        let lane = stacked ? PopupLane.pick(above, below, height: size.height) : PopupLane.pick(below, above, height: size.height)
        return lane.frame(x: completion.minX, size: size, screen: anchor.screen)
    }
}
