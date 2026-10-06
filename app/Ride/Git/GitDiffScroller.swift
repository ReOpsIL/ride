import AppKit

final class GitDiffScroller: NSScrollView {
    private var fitting = false
    private var homeAfterLayout = false

    override func tile() {
        super.tile()
        fitDocument()
        if homeAfterLayout {
            homeAfterLayout = false
            scrollHome()
        }
    }

    func showFromStart() {
        (documentView as? NSTextView)?.setSelectedRange(NSRange(location: 0, length: 0))
        fitDocument()
        scrollHome()
        homeAfterLayout = true
        needsLayout = true
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

    private func scrollHome() {
        contentView.scroll(to: .zero)
        reflectScrolledClipView(contentView)
    }
}
