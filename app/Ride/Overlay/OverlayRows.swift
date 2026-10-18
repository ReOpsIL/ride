import AppKit

struct OverlaySlice {
    var rows: [OverlayChipRow]
    var notes: [OverlayNoteRow]
    var level: ProblemLevel
}

struct OverlayRows {
    var slices: [OverlaySlice]
    var lineHeight: CGFloat
    var font: NSFont

    var height: CGFloat {
        CGFloat(slices.reduce(0) { $0 + $1.rows.count + $1.notes.count }) * lineHeight
    }

    func draw(in fragment: NSTextLayoutFragment, at point: CGPoint, below extra: CGFloat) {
        let line = fragment.textLineFragments.last
        var y = point.y + (line?.typographicBounds.maxY ?? 0) + extra
        let maxX = point.x + fragment.layoutFragmentFrame.width - 4
        for slice in slices {
            y = draw(slice, fragment: fragment, point: point, y: y, maxX: maxX)
        }
    }

    private func draw(
        _ slice: OverlaySlice,
        fragment: NSTextLayoutFragment,
        point: CGPoint,
        y start: CGFloat,
        maxX: CGFloat
    ) -> CGFloat {
        var y = start
        for row in slice.rows {
            for chip in row.chips {
                drawChip(chip, level: slice.level, fragment: fragment, point: point, rowY: y, maxX: maxX)
            }
            y += lineHeight
        }
        for note in slice.notes {
            y = drawNote(note, fragment: fragment, point: point, y: y, maxX: maxX)
        }
        return y
    }

    private func drawChip(
        _ chip: OverlayChip,
        level: ProblemLevel,
        fragment: NSTextLayoutFragment,
        point: CGPoint,
        rowY: CGFloat,
        maxX: CGFloat
    ) {
        let color = OverlayChrome.color(chip.kind, level: level)
        let x = glyphX(chip.offset, fragment: fragment, point: point)
        guard x < maxX - 8 else {
            return
        }
        let attrs = OverlayChrome.attrs(font, color)
        let text = OverlayFit.fitted(chip.text, width: max(maxX - x - 10, 8), attributes: attrs)
        let size = (text as NSString).size(withAttributes: attrs)
        let rect = NSRect(x: x, y: rowY + 3, width: min(size.width + 8, maxX - x), height: max(lineHeight - 4, 1))
        color.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        OverlayChrome.arrow(at: CGPoint(x: x + 5, y: rowY + 1), color: color)
        (text as NSString).draw(at: CGPoint(x: rect.minX + 4, y: rect.midY - size.height / 2), withAttributes: attrs)
    }

    private func drawNote(
        _ note: OverlayNoteRow,
        fragment: NSTextLayoutFragment,
        point: CGPoint,
        y: CGFloat,
        maxX: CGFloat
    ) -> CGFloat {
        let left = point.x + (fragment.textLineFragments.first?.typographicBounds.minX ?? 0)
        let (prefix, color) = OverlayChrome.heading(note.level)
        let prefixAttrs = OverlayChrome.attrs(Tokens.nsMono(font.pointSize, weight: .bold), color)
        let prefixText = prefix + " "
        let prefixWidth = (prefixText as NSString).size(withAttributes: prefixAttrs).width
        var limit = maxX - left - prefixWidth
        if note.fixTitle != nil {
            limit -= 48
        }
        var body = note.message
        if let line = note.jumpLine {
            body += " ↓ line \(line)"
        }
        let bodyAttrs = OverlayChrome.attrs(font, ThemeStore.shared.chrome.textTertiary)
        let fitted = OverlayFit.fitted(body, width: max(limit, 8), attributes: bodyAttrs)
        let size = (fitted as NSString).size(withAttributes: bodyAttrs)
        let textY = y + max(0, (lineHeight - size.height) / 2)
        (prefixText as NSString).draw(at: CGPoint(x: left, y: textY), withAttributes: prefixAttrs)
        (fitted as NSString).draw(at: CGPoint(x: left + prefixWidth, y: textY), withAttributes: bodyAttrs)
        if note.fixTitle != nil {
            drawFix(at: CGPoint(x: left + prefixWidth + size.width + 8, y: y))
        }
        return y + lineHeight
    }

    private func drawFix(at origin: CGPoint) {
        let color = ThemeStore.shared.chrome.success
        let attrs = OverlayChrome.attrs(font, color)
        let text = "Fix" as NSString
        let size = text.size(withAttributes: attrs)
        let rect = NSRect(x: origin.x, y: origin.y + 2, width: size.width + 10, height: max(lineHeight - 4, 1))
        color.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        text.draw(at: CGPoint(x: rect.minX + 5, y: rect.midY - size.height / 2), withAttributes: attrs)
    }

    private func glyphX(_ offset: Int, fragment: NSTextLayoutFragment, point: CGPoint) -> CGFloat {
        let line = fragment.textLineFragments.last { $0.characterRange.location <= offset } ?? fragment.textLineFragments.first
        guard let line else {
            return point.x
        }
        let caret = line.locationForCharacter(at: offset)
        return point.x + line.typographicBounds.minX + caret.x
    }
}

enum OverlayChrome {
    static func color(_ kind: OverlayChipKind, level: ProblemLevel) -> NSColor {
        let chrome = ThemeStore.shared.chrome
        switch kind {
        case .primary:
            return level == .error ? chrome.error : chrome.warning
        case .secondary, .external:
            return chrome.accent
        case .note:
            return chrome.textTertiary
        }
    }

    static func heading(_ level: StoredNoteLevel) -> (String, NSColor) {
        let chrome = ThemeStore.shared.chrome
        switch level {
        case .help:
            return ("help:", chrome.success)
        case .note:
            return ("note:", chrome.textTertiary)
        case .error:
            return ("error:", chrome.textTertiary)
        case .warning:
            return ("warning:", chrome.textTertiary)
        }
    }

    static func attrs(_ font: NSFont, _ color: NSColor) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: color]
    }

    static func arrow(at tip: CGPoint, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: tip)
        path.line(to: CGPoint(x: tip.x - 3.5, y: tip.y + 5))
        path.line(to: CGPoint(x: tip.x + 3.5, y: tip.y + 5))
        path.close()
        color.setFill()
        path.fill()
    }
}

enum OverlayFit {
    static func fitted(_ text: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> String {
        if (text as NSString).size(withAttributes: attributes).width <= width {
            return text
        }
        var end = text.count
        while end > 0 {
            let trial = String(text.prefix(end)) + "…"
            if (trial as NSString).size(withAttributes: attributes).width <= width {
                return trial
            }
            end -= 1
        }
        return "…"
    }
}
