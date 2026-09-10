import AppKit

final class HiddenFragment: NSTextLayoutFragment {
    override var layoutFragmentFrame: CGRect {
        var frame = super.layoutFragmentFrame
        frame.size.height = 0
        return frame
    }

    override func draw(at point: CGPoint, in context: CGContext) {}
}

final class FoldHeadFragment: NSTextLayoutFragment {
    override func draw(at point: CGPoint, in context: CGContext) {
        super.draw(at: point, in: context)
        guard let line = textLineFragments.first else {
            return
        }
        let bounds = line.typographicBounds
        let label = " ⋯ " as NSString
        let font = NSFont.monospacedSystemFont(ofSize: max(bounds.height * 0.55, 9), weight: .semibold)
        let color = ThemeStore.shared.chrome.accent
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = label.size(withAttributes: attrs)
        let origin = CGPoint(x: point.x + bounds.maxX + 6, y: point.y + bounds.midY - size.height / 2)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        color.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: NSRect(x: origin.x - 2, y: origin.y, width: size.width + 4, height: size.height), xRadius: 4, yRadius: 4).fill()
        label.draw(at: origin, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class FoldLayoutDelegate: NSObject, NSTextLayoutManagerDelegate {
    weak var view: RideTextView?

    func textLayoutManager(_ textLayoutManager: NSTextLayoutManager, textLayoutFragmentFor location: NSTextLocation, in textElement: NSTextElement) -> NSTextLayoutFragment {
        guard let view, !view.folds.isEmpty, let storage = view.textContentStorage, let range = textElement.elementRange else {
            return NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange)
        }
        let start = storage.offset(from: storage.documentRange.location, to: range.location)
        let end = storage.offset(from: storage.documentRange.location, to: range.endLocation)
        let paragraph = NSRange(location: start, length: end - start)
        if view.folds.hides(paragraph) {
            return HiddenFragment(textElement: textElement, range: range)
        }
        if view.folds.startsFold(at: paragraph) {
            return FoldHeadFragment(textElement: textElement, range: range)
        }
        return NSTextLayoutFragment(textElement: textElement, range: range)
    }
}

extension RideTextView {
    func refreshFolds() {
        guard let tlm = textLayoutManager else {
            return
        }
        tlm.invalidateLayout(for: tlm.documentRange)
        needsLayout = true
        needsDisplay = true
        enclosingScrollView?.contentView.needsDisplay = true
    }
}
