import AppKit

enum WhitespaceMarks {
    static func draw(in view: RideTextView, rect: NSRect) {
        guard view.showWhitespace, let tlm = view.textLayoutManager, let storage = view.textContentStorage else {
            return
        }
        let ns: NSString = view.textStorage?.mutableString ?? ""
        let origin = view.textContainerOrigin
        let attributes: [NSAttributedString.Key: Any] = [.font: view.baseFont, .foregroundColor: ThemeStore.shared.editor.indentGuide]
        let start = tlm.textViewportLayoutController.viewportRange?.location ?? tlm.documentRange.location
        tlm.enumerateTextLayoutFragments(from: start, options: [.ensuresLayout]) { fragment in
            let frame = fragment.layoutFragmentFrame.offsetBy(dx: origin.x, dy: origin.y)
            if frame.minY > rect.maxY {
                return false
            }
            if frame.maxY >= rect.minY {
                let base = storage.offset(from: storage.documentRange.location, to: fragment.rangeInElement.location)
                drawMarks(fragment, base: base, text: ns, origin: frame.origin, attributes: attributes)
            }
            return true
        }
    }

    private static func drawMarks(_ fragment: NSTextLayoutFragment, base: Int, text: NSString, origin: NSPoint, attributes: [NSAttributedString.Key: Any]) {
        for line in fragment.textLineFragments {
            let range = line.characterRange
            for offset in range.location..<NSMaxRange(range) where base + offset < text.length {
                guard let mark = symbol(for: text.character(at: base + offset)) else {
                    continue
                }
                let point = line.locationForCharacter(at: offset)
                let at = NSPoint(x: origin.x + line.typographicBounds.minX + point.x, y: origin.y + line.typographicBounds.minY)
                (mark as NSString).draw(at: at, withAttributes: attributes)
            }
        }
    }

    static func symbol(for character: unichar) -> String? {
        switch character {
        case 32: return "·"
        case 9: return "→"
        default: return nil
        }
    }
}
