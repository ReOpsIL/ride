import AppKit

extension HighlightApply {
    private static weak var markedView: RideTextView?
    private static var markedRange = NSRange(location: 0, length: 0)

    static func markLine(_ view: RideTextView, line: Int) {
        clearMarkedLine()
        let starts = view.lineIndex().starts
        guard line >= 1, line <= starts.count, let tlm = view.textLayoutManager else {
            return
        }
        let start = starts[line - 1]
        let end = line < starts.count ? starts[line] : (view.string as NSString).length
        let range = NSRange(location: start, length: max(0, end - start))
        guard range.length > 0, let textRange = view.textRange(utf16: range) else {
            return
        }
        tlm.addRenderingAttribute(
            .backgroundColor,
            value: ThemeStore.shared.chrome.accent.withAlphaComponent(0.25),
            for: textRange
        )
        markedView = view
        markedRange = range
        view.needsDisplay = true
    }

    static func clearMarkedLine() {
        guard let view = markedView, let tlm = view.textLayoutManager else {
            markedView = nil
            return
        }
        if let textRange = view.textRange(utf16: markedRange) {
            tlm.removeRenderingAttribute(.backgroundColor, for: textRange)
        }
        markedView = nil
        markedRange = NSRange(location: 0, length: 0)
        view.updateCurrentLineHighlight()
    }
}
