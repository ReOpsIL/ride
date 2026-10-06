import AppKit

final class DecoratedFragment: NSTextLayoutFragment {
    var vision: VisionLabel?
    var foldMark = false
    var ghost: GhostText?

    override var topMargin: CGFloat {
        vision?.height ?? 0
    }

    override var bottomMargin: CGFloat {
        ghost?.extraHeight(in: self) ?? 0
    }

    override var renderingSurfaceBounds: CGRect {
        let bounds = super.renderingSurfaceBounds
        return ghost?.surface(bounds, in: self) ?? bounds
    }

    override func draw(at point: CGPoint, in context: CGContext) {
        super.draw(at: point, in: context)
        if foldMark, let line = textLineFragments.first {
            FoldEllipsis.draw(line: line, at: point, in: context)
        }
        guard vision != nil || ghost != nil else {
            return
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        vision?.draw(at: point)
        ghost?.draw(in: self, at: point)
        NSGraphicsContext.restoreGraphicsState()
    }

    func containsLabel(at local: CGPoint) -> Bool {
        vision?.frame.contains(local) ?? false
    }

    static func make(
        textElement: NSTextElement,
        range: NSTextRange,
        vision: VisionLabel?,
        foldMark: Bool,
        ghost: GhostText?
    ) -> NSTextLayoutFragment {
        guard vision != nil || foldMark || ghost != nil else {
            return NSTextLayoutFragment(textElement: textElement, range: range)
        }
        let fragment = DecoratedFragment(textElement: textElement, range: range)
        fragment.vision = vision
        fragment.foldMark = foldMark
        fragment.ghost = ghost
        return fragment
    }
}
