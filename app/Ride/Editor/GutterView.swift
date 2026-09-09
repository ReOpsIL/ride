import AppKit

final class GutterView: NSView {
    weak var textView: RideTextView?
    private var viewport: NSTextViewportLayoutController?

    override var isFlipped: Bool { true }

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
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let currentLine = lineAndColumn(in: textView.string, utf16: textView.selectedRange().location).0
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: theme.editor.gutterText,
        ]
        let currentAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: theme.editor.gutterCurrent,
        ]
        let start = viewport?.viewportRange?.location ?? tlm.documentRange.location
        tlm.enumerateTextLayoutFragments(from: start, options: [.ensuresLayout]) { fragment in
            let utf16 = storage.map { $0.offset(from: $0.documentRange.location, to: fragment.rangeInElement.location) } ?? 0
            var lineNo = lineAndColumn(in: textView.string, utf16: utf16).0
            for lineFragment in fragment.textLineFragments {
                var r = lineFragment.typographicBounds
                r.origin.x = 0
                r.origin.y += fragment.layoutFragmentFrame.minY + origin.y
                r.size.width = bounds.width
                let dest = convert(r, from: textView)
                if dest.intersects(dirtyRect) {
                    let label = "\(lineNo)" as NSString
                    let style = lineNo == currentLine ? currentAttrs : attrs
                    let size = label.size(withAttributes: style)
                    label.draw(
                        at: CGPoint(x: bounds.width - size.width - 8, y: dest.midY - size.height / 2),
                        withAttributes: style
                    )
                }
                lineNo += 1
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
}
