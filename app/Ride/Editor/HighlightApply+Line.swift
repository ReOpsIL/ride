import AppKit

extension HighlightApply {
    private static weak var markedView: RideTextView?
    private static var markedRange = NSRange(location: 0, length: 0)

    static func markLine(_ view: RideTextView, line: Int) {
        clearMarkedLine()
        guard let tlm = view.textLayoutManager, let range = view.lineRange(line), range.length > 0,
              let textRange = view.textRange(utf16: range)
        else {
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
