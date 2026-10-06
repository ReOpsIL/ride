import AppKit

struct GhostText {
    let lines: [String]
    let caretIndex: Int
    let font: NSFont
    let color: NSColor
    let lineHeight: CGFloat

    func extraHeight(in fragment: NSTextLayoutFragment) -> CGFloat {
        CGFloat(max(lines.count - 1, 0)) * rowHeight(in: fragment)
    }

    func surface(_ bounds: CGRect, in fragment: NSTextLayoutFragment) -> CGRect {
        var bounds = bounds
        let widest = lines.map { ($0 as NSString).size(withAttributes: attributes).width }.max() ?? 0
        let start = caretLine(in: fragment)?.typographicBounds.maxX ?? 0
        bounds.size.width = max(bounds.width, start + widest + rowHeight(in: fragment))
        bounds.size.height = max(bounds.height, fragment.layoutFragmentFrame.height + extraHeight(in: fragment))
        return bounds
    }

    func draw(in fragment: NSTextLayoutFragment, at point: CGPoint) {
        guard let line = caretLine(in: fragment), let first = lines.first else {
            return
        }
        let caret = line.locationForCharacter(at: caretIndex)
        (first as NSString).draw(
            at: CGPoint(x: point.x + line.typographicBounds.minX + caret.x, y: point.y + line.typographicBounds.minY),
            withAttributes: attributes
        )
        let left = point.x + (fragment.textLineFragments.first?.typographicBounds.minX ?? 0)
        let below = point.y + (fragment.textLineFragments.last?.typographicBounds.maxY ?? line.typographicBounds.maxY)
        let row = rowHeight(in: fragment)
        for (offset, text) in lines.dropFirst().enumerated() {
            (text as NSString).draw(at: CGPoint(x: left, y: below + CGFloat(offset) * row), withAttributes: attributes)
        }
    }

    private var attributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: color]
    }

    private func rowHeight(in fragment: NSTextLayoutFragment) -> CGFloat {
        fragment.textLineFragments.first?.typographicBounds.height ?? lineHeight
    }

    private func caretLine(in fragment: NSTextLayoutFragment) -> NSTextLineFragment? {
        fragment.textLineFragments.last { $0.characterRange.location <= caretIndex } ?? fragment.textLineFragments.first
    }
}

extension RideTextView {
    func ghostText(at paragraph: NSRange) -> GhostText? {
        guard let ghost = inlineGhost, owns(paragraph, location: ghost.location) else {
            return nil
        }
        let space = String(repeating: " ", count: tabWidth)
        return GhostText(
            lines: ghost.lines.map { $0.replacingOccurrences(of: "\t", with: space) },
            caretIndex: ghost.location - paragraph.location,
            font: baseFont,
            color: ThemeStore.shared.chrome.textTertiary,
            lineHeight: ceil(baseFont.ascender - baseFont.descender + baseFont.leading)
        )
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
