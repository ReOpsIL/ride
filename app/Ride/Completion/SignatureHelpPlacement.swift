import AppKit

enum SignatureHelpPlacement {
    static func frame(size: NSSize, caret: NSRect, screen: NSRect, below: Bool) -> NSRect {
        let clear = CompletionPlacement.gap(caret: caret)
        let above = PopupLane.above(from: caret.maxY + clear, screen: screen)
        let under = PopupLane.below(from: caret.minY - clear, screen: screen)
        let lane = below ? PopupLane.pick(under, above, height: size.height) : PopupLane.pick(above, under, height: size.height)
        return lane.frame(x: caret.minX - Tokens.Space.m, size: size, screen: screen)
    }
}
