import AppKit

final class GutterView: NSView {
    weak var textView: RideTextView?
    var diagnosticLines: [Int: DiagnosticLevel] = [:] {
        didSet { needsDisplay = true }
    }
    private var viewport: NSTextViewportLayoutController?
    static let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    static let currentFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
    static let glyphColumn: CGFloat = 14
    static let trailing: CGFloat = 8

    override var isFlipped: Bool { true }

    static func width(digits: Int) -> CGFloat {
        let digit = ("0" as NSString).size(withAttributes: [.font: font]).width
        return glyphColumn + digit * CGFloat(max(digits, 3)) + trailing + 4
    }

    func attach(textView: RideTextView) {
        self.textView = textView
        viewport = textView.textLayoutManager?.textViewportLayoutController
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let theme = ThemeStore.shared.theme
        theme.editor.background.setFill()
        dirtyRect.fill()
        guard let textView, let tlm = textView.textLayoutManager else {
            return
        }
        let storage = textView.textContentStorage
        let origin = textView.textContainerOrigin
        let index = textView.lineIndex()
        let currentLine = index.line(at: textView.selectedRange().location)
        let attrs: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: theme.editor.gutterText]
        let currentAttrs: [NSAttributedString.Key: Any] = [.font: Self.currentFont, .foregroundColor: theme.editor.gutterCurrent]
        let start = viewport?.viewportRange?.location ?? tlm.documentRange.location
        tlm.enumerateTextLayoutFragments(from: start, options: [.ensuresLayout]) { fragment in
            let utf16 = storage.map { $0.offset(from: $0.documentRange.location, to: fragment.rangeInElement.location) } ?? 0
            let lineNo = index.line(at: utf16)
            if let lineFragment = fragment.textLineFragments.first {
                var r = lineFragment.typographicBounds
                r.origin.x = 0
                r.origin.y += fragment.layoutFragmentFrame.minY + origin.y
                r.size.width = bounds.width
                let dest = convert(r, from: textView)
                if dest.intersects(dirtyRect) {
                    drawLine(lineNo, at: dest, attrs: lineNo == currentLine ? currentAttrs : attrs, theme: theme)
                }
            }
            if let end = viewport?.viewportRange?.endLocation,
               fragment.rangeInElement.endLocation.compare(end) != .orderedAscending
            {
                return false
            }
            return true
        }
        theme.chrome.border.setStroke()
        let edge = NSBezierPath()
        edge.move(to: CGPoint(x: bounds.maxX - 0.5, y: 0))
        edge.line(to: CGPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        edge.stroke()
    }

    private func drawLine(_ lineNo: Int, at dest: NSRect, attrs: [NSAttributedString.Key: Any], theme: Theme) {
        let label = "\(lineNo)" as NSString
        let size = label.size(withAttributes: attrs)
        label.draw(
            at: CGPoint(x: bounds.width - size.width - Self.trailing, y: dest.midY - size.height / 2),
            withAttributes: attrs
        )
        if let level = diagnosticLines[lineNo] {
            let color = level == .error ? theme.chrome.error : theme.chrome.warning
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: 5, y: dest.midY - 3, width: 6, height: 6)).fill()
        }
    }
}
