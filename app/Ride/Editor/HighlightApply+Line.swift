import AppKit

extension HighlightApply {
    private static weak var markedView: RideTextView?

    static func markLine(_ view: RideTextView, line: Int) {
        clearMarkedLine()
        guard let range = view.lineRange(line), range.length > 0 else {
            return
        }
        view.setBackground(.markedLine, ranges: [range])
        markedView = view
    }

    static func clearMarkedLine() {
        markedView?.setBackground(.markedLine, ranges: [])
        markedView = nil
    }
}
