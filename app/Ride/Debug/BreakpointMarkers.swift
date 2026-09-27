import AppKit

enum BreakpointMarkers {
    static func refresh(view: RideTextView, gutter: GutterView) {
        guard let path = view.hooks.binding?()?.document.fileURL?.standardizedFileURL.path else {
            gutter.breakpointLines = [:]
            return
        }
        var rows: [Int: Bool] = [:]
        for mark in DebugController.shared.breakpoints.marks(path: path) {
            rows[Int(mark.line)] = mark.verified
        }
        gutter.breakpointLines = rows
    }
}
