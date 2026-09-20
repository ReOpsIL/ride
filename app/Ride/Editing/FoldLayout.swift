import AppKit

final class HiddenFragment: NSTextLayoutFragment {
    override var layoutFragmentFrame: CGRect {
        var frame = super.layoutFragmentFrame
        frame.size.height = 0
        return frame
    }

    override func draw(at point: CGPoint, in context: CGContext) {}
}

enum FoldEllipsis {
    static func draw(line: NSTextLineFragment, at point: CGPoint, in context: CGContext) {
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

final class FoldHeadFragment: NSTextLayoutFragment {
    override func draw(at point: CGPoint, in context: CGContext) {
        super.draw(at: point, in: context)
        guard let line = textLineFragments.first else {
            return
        }
        FoldEllipsis.draw(line: line, at: point, in: context)
    }
}

final class VisionFragment: NSTextLayoutFragment {
    var extra: CGFloat = 0
    var label = ""
    var indent: CGFloat = 0
    var padding: CGFloat = 5
    var font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    var showsFoldMark = false
    private(set) var labelFrame = CGRect.zero

    override var topMargin: CGFloat { extra }

    override func draw(at point: CGPoint, in context: CGContext) {
        super.draw(at: point, in: context)
        drawLabel(at: point, in: context)
        if showsFoldMark, let line = textLineFragments.first {
            FoldEllipsis.draw(line: line, at: point, in: context)
        }
    }

    func containsLabel(at local: CGPoint) -> Bool {
        labelFrame.contains(local)
    }

    private func drawLabel(at point: CGPoint, in context: CGContext) {
        let text = label as NSString
        let color = ThemeStore.shared.chrome.textTertiary
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = text.size(withAttributes: attrs)
        labelFrame = VisionLayout.labelRect(
            extraHeight: extra,
            indent: indent,
            labelSize: size,
            padding: padding
        )
        let origin = CGPoint(x: point.x + labelFrame.minX, y: point.y + labelFrame.minY)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        text.draw(at: origin, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class FoldLayoutDelegate: NSObject, NSTextLayoutManagerDelegate {
    weak var view: RideTextView?

    func textLayoutManager(_ textLayoutManager: NSTextLayoutManager, textLayoutFragmentFor location: NSTextLocation, in textElement: NSTextElement) -> NSTextLayoutFragment {
        guard let view, let storage = view.textContentStorage, let range = textElement.elementRange else {
            return NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange)
        }
        let start = storage.offset(from: storage.documentRange.location, to: range.location)
        let end = storage.offset(from: storage.documentRange.location, to: range.endLocation)
        let paragraph = NSRange(location: start, length: end - start)
        if !view.folds.isEmpty, view.folds.hides(paragraph) {
            return HiddenFragment(textElement: textElement, range: range)
        }
        let foldHead = !view.folds.isEmpty && view.folds.startsFold(at: paragraph)
        if let line = view.visionLine(at: paragraph) {
            let fragment = VisionFragment(textElement: textElement, range: range)
            fragment.extra = view.visionLineHeight
            fragment.label = line.label
            fragment.indent = view.visionIndent(at: paragraph)
            fragment.padding = view.textContainer?.lineFragmentPadding ?? 5
            fragment.font = view.visionFont
            fragment.showsFoldMark = foldHead
            return fragment
        }
        if foldHead {
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
