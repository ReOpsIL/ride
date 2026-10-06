import AppKit

final class GitDiffScroller: NSScrollView {
    private var fitting = false

    override func tile() {
        super.tile()
        fitDocument()
    }

    func fitDocument() {
        guard !fitting, let textView = documentView as? NSTextView else {
            return
        }
        fitting = true
        defer { fitting = false }
        let visible = contentSize
        if textView.minSize != visible {
            textView.minSize = visible
        }
        textView.sizeToFit()
    }
}
