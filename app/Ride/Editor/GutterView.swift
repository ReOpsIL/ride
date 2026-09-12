import AppKit

final class GutterView: NSView {
    weak var textView: RideTextView?
    var diagnosticLines: [Int: DiagnosticLevel] = [:] {
        didSet { needsDisplay = true }
    }
    var runMarkers: [Int: TestMarkerRow] = [:] {
        didSet {
            if runMarkers != oldValue {
                needsDisplay = true
            }
        }
    }
    private var viewport: NSTextViewportLayoutController?
    static let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    static let currentFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
    static let glyphColumn: CGFloat = 14
    static let markerColumn: CGFloat = 13
    static let trailing: CGFloat = 8

    override var isFlipped: Bool { true }

    static func width(digits: Int) -> CGFloat {
        let digit = ("0" as NSString).size(withAttributes: [.font: font]).width
        return markerColumn + glyphColumn + digit * CGFloat(max(digits, 3)) + trailing + 4
    }

    func attach(textView: RideTextView) {
        self.textView = textView
        viewport = textView.textLayoutManager?.textViewportLayoutController
        FoldController.shared.refreshStarts(textView)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let theme = ThemeStore.shared.theme
        theme.editor.background.setFill()
        dirtyRect.fill()
        if let textView, textView.folds.startsDirty {
            FoldController.shared.refreshStarts(textView)
        }
        guard let textView else {
            return
        }
        let index = textView.lineIndex()
        let currentLine = index.line(at: textView.selectedRange().location)
        let attrs: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: theme.editor.gutterText]
        let currentAttrs: [NSAttributedString.Key: Any] = [.font: Self.currentFont, .foregroundColor: theme.editor.gutterCurrent]
        enumerateVisibleLines { lineNo, dest in
            if dest.intersects(dirtyRect) {
                drawLine(lineNo, at: dest, attrs: lineNo == currentLine ? currentAttrs : attrs, theme: theme)
            }
            return true
        }
        theme.chrome.border.setStroke()
        let edge = NSBezierPath()
        edge.move(to: CGPoint(x: bounds.maxX - 0.5, y: 0))
        edge.line(to: CGPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        edge.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard point.x < Self.markerColumn + Self.glyphColumn, let line = line(at: point), let textView else {
            return
        }
        if point.x < Self.markerColumn {
            runMarker(line, in: textView)
            return
        }
        if textView.folds.startsDirty {
            FoldController.shared.refreshStarts(textView)
        }
        guard textView.folds.isFoldStart(line: line) else {
            return
        }
        FoldController.shared.toggle(line: line)
    }

    private func runMarker(_ line: Int, in textView: RideTextView) {
        guard let marker = runMarkers[line], let state = textView.hooks.binding?()?.state else {
            return
        }
        state.runTestMarker(marker)
    }

    private func line(at point: NSPoint) -> Int? {
        var found: Int?
        enumerateVisibleLines { lineNo, dest in
            guard point.y >= dest.minY, point.y < dest.maxY else {
                return true
            }
            found = lineNo
            return false
        }
        return found
    }

    private func enumerateVisibleLines(_ body: (Int, NSRect) -> Bool) {
        guard let textView, let tlm = textView.textLayoutManager else {
            return
        }
        let storage = textView.textContentStorage
        let origin = textView.textContainerOrigin
        let index = textView.lineIndex()
        let start = viewport?.viewportRange?.location ?? tlm.documentRange.location
        tlm.enumerateTextLayoutFragments(from: start, options: [.ensuresLayout]) { fragment in
            let utf16 = storage.map { $0.offset(from: $0.documentRange.location, to: fragment.rangeInElement.location) } ?? 0
            let lineNo = index.line(at: utf16)
            if let lineFragment = fragment.textLineFragments.first {
                var r = lineFragment.typographicBounds
                r.origin.x = 0
                r.origin.y += fragment.layoutFragmentFrame.minY + origin.y
                r.size.width = bounds.width
                if !body(lineNo, convert(r, from: textView)) {
                    return false
                }
            }
            if let end = viewport?.viewportRange?.endLocation,
               fragment.rangeInElement.endLocation.compare(end) != .orderedAscending
            {
                return false
            }
            return true
        }
    }

    private func drawLine(_ lineNo: Int, at dest: NSRect, attrs: [NSAttributedString.Key: Any], theme: Theme) {
        let label = "\(lineNo)" as NSString
        let size = label.size(withAttributes: attrs)
        label.draw(
            at: CGPoint(x: bounds.width - size.width - Self.trailing, y: dest.midY - size.height / 2),
            withAttributes: attrs
        )
        if let textView, textView.folds.isFoldStart(line: lineNo) {
            let collapsed = textView.folds.startsFold(at: lineRange(lineNo, in: textView))
            drawChevron(collapsed: collapsed, at: dest, color: collapsed ? theme.chrome.accent : theme.editor.gutterText)
        } else if let level = diagnosticLines[lineNo] {
            let color = level == .error ? theme.chrome.error : theme.chrome.warning
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: Self.markerColumn + 5, y: dest.midY - 3, width: 6, height: 6)).fill()
        }
        if runMarkers[lineNo] != nil {
            drawRunMarker(at: dest, color: theme.chrome.accent)
        }
    }

    private func lineRange(_ line: Int, in view: RideTextView) -> NSRange {
        let starts = view.lineIndex().starts
        guard line >= 1, line <= starts.count else {
            return NSRange(location: 0, length: 0)
        }
        let start = starts[line - 1]
        let end = line < starts.count ? starts[line] : (view.string as NSString).length
        return NSRange(location: start, length: max(0, end - start))
    }

    private func drawRunMarker(at dest: NSRect, color: NSColor) {
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

    private func drawChevron(collapsed: Bool, at dest: NSRect, color: NSColor) {
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
}
