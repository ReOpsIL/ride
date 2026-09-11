import AppKit

extension EditorHostView {
    func jump(byte: UInt32) {
        let ns = Utf16.nsRange(in: textView.string, startByte: byte, endByte: byte)
        select(NSRange(location: ns.location, length: 0))
    }

    func select(_ range: NSRange) {
        let length = textView.textStorage?.length ?? 0
        let loc = min(max(range.location, 0), length)
        let len = min(max(range.length, 0), length - loc)
        let clamped = NSRange(location: loc, length: len)
        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(clamped)
        if loc == 0 {
            scroll.contentView.scroll(to: .zero)
            scroll.reflectScrolledClipView(scroll.contentView)
        } else {
            textView.scrollRangeToVisible(NSRange(location: loc, length: max(len, 1)))
        }
        textView.updateCurrentLineHighlight()
        syncGutter()
    }

    func jump(toLine line: Int) {
        let starts = textView.lineIndex().starts
        let loc = starts[min(max(line, 1), starts.count) - 1]
        select(NSRange(location: loc, length: 0))
    }

    func replaceText(_ text: String) {
        textView.string = text
        textView.lines.invalidate()
        syncGutter()
        textView.updateCurrentLineHighlight()
    }
}
