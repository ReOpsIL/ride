import AppKit

extension GutterView {
    func line(at point: NSPoint) -> Int? {
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

    func enumerateVisibleLines(_ body: (Int, NSRect) -> Bool) {
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

    func lineRange(_ line: Int, in view: RideTextView) -> NSRange {
        let starts = view.lineIndex().starts
        guard line >= 1, line <= starts.count else {
            return NSRange(location: 0, length: 0)
        }
        let start = starts[line - 1]
        let end = line < starts.count ? starts[line] : (view.string as NSString).length
        return NSRange(location: start, length: max(0, end - start))
    }
}
