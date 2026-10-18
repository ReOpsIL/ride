import AppKit

final class DecoratedFragment: NSTextLayoutFragment {
    var vision: VisionLabel?
    var foldMark = false
    var ghost: GhostText?
    var overlay: OverlayRows?

    override var topMargin: CGFloat {
        vision?.height ?? 0
    }

    override var bottomMargin: CGFloat {
        (ghost?.extraHeight(in: self) ?? 0) + (overlay?.height ?? 0)
    }

    override var renderingSurfaceBounds: CGRect {
        var bounds = super.renderingSurfaceBounds
        if let ghost {
            bounds = ghost.surface(bounds, in: self)
        }
        if let overlay {
            bounds = overlay.surface(bounds, in: self)
        }
        bounds.size.height = max(bounds.height, layoutFragmentFrame.height)
        return bounds
    }

    override func draw(at point: CGPoint, in context: CGContext) {
        super.draw(at: point, in: context)
        if foldMark, let line = textLineFragments.first {
            FoldEllipsis.draw(line: line, at: point, in: context)
        }
        guard vision != nil || ghost != nil || overlay != nil else {
            return
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        vision?.draw(at: point)
        ghost?.draw(in: self, at: point)
        overlay?.draw(in: self, at: point, below: ghost?.extraHeight(in: self) ?? 0)
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
        ghost: GhostText?,
        overlay: OverlayRows?
    ) -> NSTextLayoutFragment {
        guard vision != nil || foldMark || ghost != nil || overlay != nil else {
            return NSTextLayoutFragment(textElement: textElement, range: range)
        }
        let fragment = DecoratedFragment(textElement: textElement, range: range)
        fragment.vision = vision
        fragment.foldMark = foldMark
        fragment.ghost = ghost
        fragment.overlay = overlay
        return fragment
    }
}
