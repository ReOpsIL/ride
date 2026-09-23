import AppKit

extension GutterView {
    func drawRunMarker(at dest: NSRect, color: NSColor) {
        let cx = Self.markerColumn / 2
        let cy = dest.midY
        let path = NSBezierPath()
        path.move(to: CGPoint(x: cx - 3, y: cy - 4))
        path.line(to: CGPoint(x: cx + 4, y: cy))
        path.line(to: CGPoint(x: cx - 3, y: cy + 4))
        path.close()
        color.setFill()
        path.fill()
    }

    func drawChevron(collapsed: Bool, at dest: NSRect, color: NSColor) {
        let cx = Self.markerColumn + Self.glyphColumn / 2
        let cy = dest.midY
        let path = NSBezierPath()
        if collapsed {
            path.move(to: CGPoint(x: cx - 2, y: cy - 3.5))
            path.line(to: CGPoint(x: cx + 3, y: cy))
            path.line(to: CGPoint(x: cx - 2, y: cy + 3.5))
        } else {
            path.move(to: CGPoint(x: cx - 3.5, y: cy - 2))
            path.line(to: CGPoint(x: cx + 3.5, y: cy - 2))
            path.line(to: CGPoint(x: cx, y: cy + 3))
        }
        path.close()
        color.setFill()
        path.fill()
    }

    func drawBulb(at dest: NSRect, color: NSColor) {
        let cx = Self.markerColumn + Self.glyphColumn / 2
        let cy = dest.midY
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - 3, y: cy - 4.5, width: 6, height: 6)).fill()
        NSBezierPath(rect: NSRect(x: cx - 2, y: cy + 1.5, width: 4, height: 1.5)).fill()
        NSBezierPath(rect: NSRect(x: cx - 1.5, y: cy + 3.5, width: 3, height: 1.5)).fill()
    }

    func drawNumber(_ lineNo: Int, at dest: NSRect, attrs: [NSAttributedString.Key: Any]) {
        let label = "\(lineNo)" as NSString
        let size = label.size(withAttributes: attrs)
        label.draw(
            at: CGPoint(x: bounds.width - size.width - Self.trailing, y: dest.midY - size.height / 2),
            withAttributes: attrs
        )
    }

    func drawBreakpoint(verified: Bool, at dest: NSRect, color: NSColor) {
        let rect = NSRect(
            x: Self.markerColumn + Self.glyphColumn,
            y: dest.midY - 7,
            width: max(0, bounds.width - Self.markerColumn - Self.glyphColumn - 2),
            height: 14
        )
        let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        color.setFill()
        color.setStroke()
        if verified {
            path.fill()
            return
        }
        path.lineWidth = 1.5
        path.stroke()
    }
}
