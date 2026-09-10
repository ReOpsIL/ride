import AppKit

enum EditorCommand {
    static func apply(_ result: EditResult, to view: RideTextView) {
        guard !result.changes.isEmpty else {
            view.setSelectedRange(result.selection)
            return
        }
        let session = CompletionSession.shared
        let previous = session.editSource
        session.editSource = .completion
        view.undoManager?.beginUndoGrouping()
        for change in result.changes.reversed() {
            view.replaceText(in: change.range, with: change.text)
        }
        view.undoManager?.endUndoGrouping()
        session.editSource = previous
        let length = (view.string as NSString).length
        let location = min(max(result.selection.location, 0), length)
        let span = min(max(result.selection.length, 0), length - location)
        view.setSelectedRange(NSRange(location: location, length: span))
        view.scrollRangeToVisible(NSRange(location: location, length: 0))
    }

    static func indentUnit(for view: RideTextView, language: BufferLanguage) -> String {
        language == .make ? "\t" : String(repeating: " ", count: view.tabWidth)
    }
}
