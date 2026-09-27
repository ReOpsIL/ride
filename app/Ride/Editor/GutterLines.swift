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
            if fragment.layoutFragmentFrame.height > 0, let lineFragment = fragment.textLineFragments.first {
                var r = lineFragment.typographicBounds
                r.origin.y += fragment.layoutFragmentFrame.minY + origin.y
                let line = convert(r, from: textView)
                let row = NSRect(x: 0, y: line.minY, width: bounds.width, height: line.height)
                if !body(lineNo, row) {
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
}
