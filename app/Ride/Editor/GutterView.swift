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
        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()
        guard let textView, let tlm = textView.textLayoutManager else {
            return
        }
        let storage = textView.textContentStorage
        let origin = textView.textContainerOrigin
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor,
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
                    let size = label.size(withAttributes: attrs)
                    label.draw(
                        at: CGPoint(x: bounds.width - size.width - 6, y: dest.midY - size.height / 2),
                        withAttributes: attrs
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
        NSColor.separatorColor.setStroke()
        let edge = NSBezierPath()
        edge.move(to: CGPoint(x: bounds.maxX - 0.5, y: 0))
        edge.line(to: CGPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        edge.stroke()
    }
}
