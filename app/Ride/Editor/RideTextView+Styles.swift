import AppKit

struct ViewportAnchor {
    let offset: Int
    let distance: CGFloat
}

extension RideTextView {
    func editStyles(_ body: (NSTextStorage) -> Void) {
        guard let storage = textContentStorage?.textStorage else {
            return
        }
        let anchor = viewportAnchor()
        storage.beginEditing()
        body(storage)
        let edited = storage.editedRange
        storage.endEditing()
        guard let anchor, edited.location != NSNotFound, edited.location < anchor.offset else {
            return
        }
        settleLayout(from: edited.location, to: min(NSMaxRange(edited), anchor.offset))
        keep(anchor)
    }

    private var visibleTop: CGFloat {
        visibleRect.minY - textContainerOrigin.y
    }

    private func viewportAnchor() -> ViewportAnchor? {
        guard let tlm = textLayoutManager, let storage = textContentStorage,
              let fragment = tlm.textLayoutFragment(for: CGPoint(x: 0, y: visibleTop))
        else {
            return nil
        }
        let offset = storage.offset(from: storage.documentRange.location, to: fragment.rangeInElement.location)
        return ViewportAnchor(offset: offset, distance: fragment.layoutFragmentFrame.minY - visibleTop)
    }

    private func settleLayout(from start: Int, to end: Int) {
        guard end > start, let range = textRange(utf16: NSRange(location: start, length: end - start)) else {
            return
        }
        textLayoutManager?.ensureLayout(for: range)
    }

    private func keep(_ anchor: ViewportAnchor) {
        guard let tlm = textLayoutManager, let location = textRange(utf16: NSRange(location: anchor.offset, length: 0))?.location else {
            return
        }
        tlm.ensureLayout(for: NSTextRange(location: location))
        guard let fragment = tlm.textLayoutFragment(for: location) else {
            return
        }
        let top = fragment.layoutFragmentFrame.minY - anchor.distance
        if abs(top - visibleTop) > 0.5 {
            scroll(NSPoint(x: visibleRect.minX, y: top + textContainerOrigin.y))
        }
    }
}
