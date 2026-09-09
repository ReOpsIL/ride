import AppKit

enum IndentGuides {
    static func draw(in view: RideTextView, rect: NSRect) {
        guard view.showIndentGuides,
              let tlm = view.textLayoutManager,
              let storage = view.textContentStorage,
              let font = view.font
        else {
            return
        }
        let unit = " ".size(withAttributes: [.font: font]).width * CGFloat(view.tabWidth)
        let origin = view.textContainerOrigin
        let padding = view.textContainer?.lineFragmentPadding ?? 5
        let ns = view.string as NSString
        let start = tlm.textViewportLayoutController.viewportRange?.location ?? tlm.documentRange.location
        var carry = 0
        ThemeStore.shared.editor.indentGuide.setFill()
        tlm.enumerateTextLayoutFragments(from: start, options: [.ensuresLayout]) { fragment in
            let utf16 = storage.offset(from: storage.documentRange.location, to: fragment.rangeInElement.location)
            let level = indentLevel(ns, at: utf16, tabWidth: view.tabWidth, carry: &carry)
            let frame = fragment.layoutFragmentFrame.offsetBy(dx: origin.x, dy: origin.y)
            if frame.minY > rect.maxY {
                return false
            }
            if frame.maxY >= rect.minY {
                for i in 0..<level {
                    let x = (origin.x + padding + unit * CGFloat(i)).rounded()
                    NSRect(x: x, y: frame.minY, width: 1, height: frame.height).fill()
                }
            }
            return true
        }
    }

    static func indentLevel(_ ns: NSString, at location: Int, tabWidth: Int, carry: inout Int) -> Int {
        var i = location
        var columns = 0
        var blank = true
        while i < ns.length {
            let c = ns.character(at: i)
            if c == 32 {
                columns += 1
            } else if c == 9 {
                columns += tabWidth
            } else {
                blank = c == 10 || c == 13
                break
            }
            i += 1
        }
        let level = blank ? carry : columns / max(tabWidth, 1)
        if !blank {
            carry = level
        }
        return level
    }
}
