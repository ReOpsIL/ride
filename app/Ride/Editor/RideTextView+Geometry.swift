import AppKit

extension RideTextView {
    override func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let window, let frame = segmentFrame(range) else {
            return super.firstRect(forCharacterRange: range, actualRange: actualRange)
        }
        actualRange?.pointee = range
        let local = frame.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
        return window.convertToScreen(convert(local, to: nil))
    }

    private func segmentFrame(_ range: NSRange) -> CGRect? {
        guard let tlm = textLayoutManager, let textRange = textRange(utf16: range) else {
            return nil
        }
        var first: CGRect?
        tlm.enumerateTextSegments(in: textRange, type: .standard, options: [.rangeNotRequired]) { _, frame, _, _ in
            first = frame
            return false
        }
        return first
    }

    func lineBand(_ range: NSRange) -> NSRect? {
        guard let tlm = textLayoutManager, let textRange = textRange(utf16: range) else {
            return nil
        }
        var band: CGRect?
        tlm.enumerateTextSegments(in: textRange, type: .standard, options: [.rangeNotRequired]) { _, frame, _, _ in
            band = band?.union(frame) ?? frame
            return true
        }
        return band.map { NSRect(x: bounds.minX, y: $0.minY + textContainerOrigin.y, width: bounds.width, height: $0.height) }
    }
}
