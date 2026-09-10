import AppKit

extension EditorPane {
    final class Coordinator: NSObject, NSTextViewDelegate {
        var document: BufferDocument
        var state: AppState
        var boundID: UUID?
        weak var textView: RideTextView?
        weak var host: EditorHostView?

        init(document: BufferDocument, state: AppState) {
            self.document = document
            self.state = state
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            document.pending = PendingEdit(
                range: affectedCharRange,
                inserted: replacementString ?? "",
                before: textView.string
            )
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? RideTextView else {
                return
            }
            document.text = view.string
            document.isDirty = true
            view.updateCurrentLineHighlight()
            host?.syncGutter()
            publishCursor(view)
            let pending = document.pending
            document.pending = nil
            if let pending {
                Underlines.shift(document: document, replacing: pending.range, with: pending.inserted.utf16.count)
                let edit = EditBuild.make(before: pending.before, utf16Range: pending.range, inserted: pending.inserted)
                SessionService.shared.applyEdit(document: document, view: view, edit: edit, inserted: pending.inserted)
                assist(view, pending: pending)
            } else {
                CompletionSession.shared.reset()
            }
            state.previewTextChanged(document, text: view.string)
            state.scheduleAutoSave()
        }

        private func assist(_ view: RideTextView, pending: PendingEdit) {
            let session = CompletionSession.shared
            session.textChanged(document: document, view: view, state: state, range: pending.range, inserted: pending.inserted)
            if session.editSource == .user {
                SignatureHelpController.shared.textChanged(document: document, view: view, inserted: pending.inserted)
                CheatSheetController.shared.textChanged(document: document, view: view)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            if let view = notification.object as? RideTextView {
                view.updateCurrentLineHighlight()
                publishCursor(view)
                CompletionSession.shared.selectionChanged(view: view)
                SignatureHelpController.shared.caretMoved(document: document, view: view)
                CheatSheetController.shared.caretMoved(view: view)
            }
        }

        func publishCursor(_ view: NSTextView) {
            let loc = view.selectedRange().location
            guard let index = (view as? RideTextView)?.lineIndex() else {
                return
            }
            let line = index.line(at: loc)
            let column = index.column(at: loc)
            if state.cursorLine != line {
                state.cursorLine = line
            }
            if state.cursorColumn != column {
                state.cursorColumn = column
            }
        }

        func viewportChanged() {
            guard let view = textView else {
                return
            }
            SessionService.shared.setVisible(document: document, view: view)
            CompletionSession.shared.viewportChanged(view: view)
            CheatSheetController.shared.viewportChanged(view: view)
            SignatureHelpController.shared.relocate(in: view)
            HoverController.shared.hide()
            state.previewViewport(line: view.firstVisibleLine())
        }
    }
}
