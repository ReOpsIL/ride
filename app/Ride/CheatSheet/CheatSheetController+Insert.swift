import AppKit

extension CheatSheetController {
    func insert() -> Bool {
        guard isVisible, let entry = popup.selectedEntry, let response, let view else {
            return false
        }
        let session = CompletionSession.shared
        session.hide()
        close()
        let caret = view.selectedRange().location
        let start = min(Utf16.utf16Offset(in: view.string, utf8: Int(response.replaceStartByte)), caret)
        session.editSource = .completion
        session.insertSnippet(entry.snippet, snippet: true, replacing: NSRange(location: start, length: caret - start), in: view)
        session.editSource = .user
        return true
    }

    func anchor(for view: RideTextView) -> CheatSheetPlacement.Anchor {
        let popup = CompletionSession.shared.popup
        let visible = popup.isVisible && popup.textView === view
        return CheatSheetPlacement.Anchor(
            completion: visible ? popup.panel.frame : nil,
            completionAboveCaret: visible && popup.isAboveCaret(in: view),
            caret: CompletionPlacement.caretRect(in: view),
            screen: CompletionPlacement.screen(for: view)
        )
    }
}
