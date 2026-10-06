import AppKit

final class GhostFragment: NSTextLayoutFragment {
    var lines: [String] = []
    var caretIndex = 0
    var font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    var color = NSColor.secondaryLabelColor
    var lineHeight: CGFloat = 16

    override var bottomMargin: CGFloat {
        CGFloat(max(lines.count - 1, 0)) * rowHeight
    }

    private var rowHeight: CGFloat {
        textLineFragments.first?.typographicBounds.height ?? lineHeight
    }

    override var renderingSurfaceBounds: CGRect {
        var bounds = super.renderingSurfaceBounds
        let widest = lines.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        bounds.size.width = max(bounds.width, (caretLine?.typographicBounds.maxX ?? 0) + widest + rowHeight)
        bounds.size.height = max(bounds.height, layoutFragmentFrame.height + bottomMargin)
        return bounds
    }

    override func draw(at point: CGPoint, in context: CGContext) {
        super.draw(at: point, in: context)
        guard let line = caretLine, let first = lines.first else {
            return
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let local = line.locationForCharacter(at: caretIndex)
        let left = point.x + (textLineFragments.first?.typographicBounds.minX ?? 0)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        (first as NSString).draw(
            at: CGPoint(x: point.x + line.typographicBounds.minX + local.x, y: point.y + line.typographicBounds.minY),
            withAttributes: attrs
        )
        let below = point.y + (textLineFragments.last?.typographicBounds.maxY ?? line.typographicBounds.maxY)
        for (offset, text) in lines.dropFirst().enumerated() {
            (text as NSString).draw(at: CGPoint(x: left, y: below + CGFloat(offset) * rowHeight), withAttributes: attrs)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private var caretLine: NSTextLineFragment? {
        textLineFragments.last { $0.characterRange.location <= caretIndex } ?? textLineFragments.first
    }
}

extension RideTextView {
    func ghostFragment(for textElement: NSTextElement, range: NSTextRange, paragraph: NSRange) -> NSTextLayoutFragment? {
        guard let ghost = inlineGhost, owns(paragraph, location: ghost.location) else {
            return nil
        }
        let fragment = GhostFragment(textElement: textElement, range: range)
        let space = String(repeating: " ", count: tabWidth)
        fragment.lines = ghost.lines.map { $0.replacingOccurrences(of: "\t", with: space) }
        fragment.caretIndex = ghost.location - paragraph.location
        fragment.font = baseFont
        fragment.color = ThemeStore.shared.chrome.textTertiary
        fragment.lineHeight = ceil(baseFont.ascender - baseFont.descender + baseFont.leading)
        return fragment
    }

    func owns(_ paragraph: NSRange, location: Int) -> Bool {
        let end = NSMaxRange(paragraph)
        if location >= paragraph.location, location < end {
            return true
        }
        let text = string as NSString
        return location == end && end == text.length && (end == 0 || text.character(at: end - 1) != 10)
    }
}
