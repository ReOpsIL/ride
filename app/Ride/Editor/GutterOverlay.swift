import AppKit

enum GutterOverlay {
    static func drawNumbers(_ items: [OverlayGutterNumber], at dest: NSRect) {
        let font = NSFont.monospacedSystemFont(ofSize: items.count > 1 ? 8 : 9, weight: .semibold)
        let size: CGFloat = items.count > 1 ? 10 : 12
        for (offset, item) in items.prefix(2).enumerated() {
            let x = GutterView.markerColumn + 1 + CGFloat(offset) * (size - 1)
            let rect = NSRect(x: x, y: dest.midY - size / 2, width: size, height: size)
            fill(item.mark.kind, warning: item.warning, rect: rect)
            let text = "\(item.mark.number)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: ThemeStore.shared.theme.editor.background,
            ]
            let textSize = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2), withAttributes: attrs)
        }
    }

    static func drawBrackets(_ items: [OverlayGutterBracket], line: Int, at dest: NSRect) {
        for item in items where line >= item.bracket.start && line <= item.bracket.end {
            stroke(item, line: line, at: dest)
        }
    }

    private static func fill(_ kind: OverlayChipKind, warning: Bool, rect: NSRect) {
        paint(kind, warning: warning).setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    private static func stroke(_ item: OverlayGutterBracket, line: Int, at dest: NSRect) {
        let path = NSBezierPath()
        path.lineWidth = 1
        let x = GutterView.markerColumn + 3
        let bracket = item.bracket
        if line == bracket.start && line == bracket.end {
            return
        }
        if line == bracket.start {
            path.move(to: CGPoint(x: x + 5, y: dest.midY))
            path.line(to: CGPoint(x: x, y: dest.midY))
            path.line(to: CGPoint(x: x, y: dest.maxY))
        } else if line == bracket.end {
            path.move(to: CGPoint(x: x, y: dest.minY))
            path.line(to: CGPoint(x: x, y: dest.midY))
            path.line(to: CGPoint(x: x + 5, y: dest.midY))
        } else {
            path.move(to: CGPoint(x: x, y: dest.minY))
            path.line(to: CGPoint(x: x, y: dest.maxY))
        }
        paint(bracket.kind, warning: item.warning).setStroke()
        path.stroke()
    }

    private static func paint(_ kind: OverlayChipKind, warning: Bool) -> NSColor {
        let chrome = ThemeStore.shared.chrome
        switch kind {
        case .primary:
            return warning ? chrome.warning : chrome.error
        case .note:
            return chrome.textTertiary
        case .secondary, .external:
            return chrome.accent
        }
    }
}
