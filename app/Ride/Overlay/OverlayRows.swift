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

    func surface(_ bounds: CGRect, in fragment: NSTextLayoutFragment) -> CGRect {
        var bounds = bounds
        bounds.size.width = max(bounds.width, rightEdge(in: fragment) + 4)
        bounds.size.height = max(bounds.height, fragment.layoutFragmentFrame.height)
        return bounds
    }

    func draw(in fragment: NSTextLayoutFragment, at point: CGPoint, below extra: CGFloat) {
        let line = fragment.textLineFragments.last
        var y = point.y + (line?.typographicBounds.maxY ?? 0) + extra
        for slice in slices {
            for row in slice.rows {
                for chip in row.chips {
                    drawChip(chip, level: slice.level, x: glyphX(chip.offset, fragment: fragment) + point.x, rowY: y)
                }
                y += lineHeight
            }
            for note in slice.notes {
                drawNote(note, left: noteLeft(fragment) + point.x, y: y)
                y += lineHeight
            }
        }
    }

    private func rightEdge(in fragment: NSTextLayoutFragment) -> CGFloat {
        let left = noteLeft(fragment)
        return slices.flatMap { slice in
            slice.rows.flatMap(\.chips).map { glyphX($0.offset, fragment: fragment) + chipWidth($0, level: slice.level) }
                + slice.notes.map { left + noteWidth($0) }
        }.max() ?? 0
    }

    private func chipWidth(_ chip: OverlayChip, level: ProblemLevel) -> CGFloat {
        (chip.text as NSString).size(withAttributes: chipAttrs(chip, level: level)).width + 8
    }

    private func chipAttrs(_ chip: OverlayChip, level: ProblemLevel) -> [NSAttributedString.Key: Any] {
        OverlayChrome.attrs(font, OverlayChrome.color(chip.kind, level: level))
    }

    private func drawChip(_ chip: OverlayChip, level: ProblemLevel, x: CGFloat, rowY: CGFloat) {
        let color = OverlayChrome.color(chip.kind, level: level)
        let attrs = chipAttrs(chip, level: level)
        let size = (chip.text as NSString).size(withAttributes: attrs)
        let rect = NSRect(x: x, y: rowY + 3, width: size.width + 8, height: max(lineHeight - 4, 1))
        color.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        OverlayChrome.arrow(at: CGPoint(x: x + 5, y: rowY + 1), color: color)
        (chip.text as NSString).draw(at: CGPoint(x: rect.minX + 4, y: rect.midY - size.height / 2), withAttributes: attrs)
    }

    private func noteLeft(_ fragment: NSTextLayoutFragment) -> CGFloat {
        fragment.textLineFragments.first?.typographicBounds.minX ?? 0
    }

    private func notePrefix(_ note: OverlayNoteRow) -> (text: String, attrs: [NSAttributedString.Key: Any]) {
        let (prefix, color) = OverlayChrome.heading(note.level)
        return (prefix + " ", OverlayChrome.attrs(Tokens.nsMono(font.pointSize, weight: .bold), color))
    }

    private func noteBody(_ note: OverlayNoteRow) -> String {
        guard let line = note.jumpLine else {
            return note.message
        }
        return note.message + " ↓ line \(line)"
    }

    private var bodyAttrs: [NSAttributedString.Key: Any] {
        OverlayChrome.attrs(font, ThemeStore.shared.chrome.textTertiary)
    }

    private func noteWidth(_ note: OverlayNoteRow) -> CGFloat {
        let prefix = notePrefix(note)
        let width = (prefix.text as NSString).size(withAttributes: prefix.attrs).width
            + (noteBody(note) as NSString).size(withAttributes: bodyAttrs).width
        return note.fixTitle == nil ? width : width + 8 + fixSize.width + 10
    }

    private func drawNote(_ note: OverlayNoteRow, left: CGFloat, y: CGFloat) {
        let prefix = notePrefix(note)
        let prefixWidth = (prefix.text as NSString).size(withAttributes: prefix.attrs).width
        let body = noteBody(note)
        let size = (body as NSString).size(withAttributes: bodyAttrs)
        let textY = y + max(0, (lineHeight - size.height) / 2)
        (prefix.text as NSString).draw(at: CGPoint(x: left, y: textY), withAttributes: prefix.attrs)
        (body as NSString).draw(at: CGPoint(x: left + prefixWidth, y: textY), withAttributes: bodyAttrs)
        if note.fixTitle != nil {
            drawFix(at: CGPoint(x: left + prefixWidth + size.width + 8, y: y))
        }
    }

    private var fixAttrs: [NSAttributedString.Key: Any] {
        OverlayChrome.attrs(font, ThemeStore.shared.chrome.success)
    }

    private var fixSize: CGSize {
        ("Fix" as NSString).size(withAttributes: fixAttrs)
    }

    private func drawFix(at origin: CGPoint) {
        let size = fixSize
        let rect = NSRect(x: origin.x, y: origin.y + 2, width: size.width + 10, height: max(lineHeight - 4, 1))
        ThemeStore.shared.chrome.success.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        ("Fix" as NSString).draw(at: CGPoint(x: rect.minX + 5, y: rect.midY - size.height / 2), withAttributes: fixAttrs)
    }

    private func glyphX(_ offset: Int, fragment: NSTextLayoutFragment) -> CGFloat {
        let line = fragment.textLineFragments.last { $0.characterRange.location <= offset } ?? fragment.textLineFragments.first
        guard let line else {
            return 0
        }
        return line.typographicBounds.minX + line.locationForCharacter(at: offset).x
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
