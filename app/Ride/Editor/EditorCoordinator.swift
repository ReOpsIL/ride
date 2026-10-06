import AppKit

extension EditorPane {
    final class Coordinator: NSObject, NSTextViewDelegate {
        let document: BufferDocument
        var state: AppState
        var inViewUpdate = false
        weak var textView: RideTextView?
        weak var host: EditorHostView?

        init(document: BufferDocument, state: AppState) {
            self.document = document
            self.state = state
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            if document.isReadOnly {
                return false
            }
            document.undo.open()
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
            let typed = document.pending
            document.pending = nil
            let pending = typed ?? replayedEdit(view)
            let edit = pending.map { EditBuild.make(before: $0.before, utf16Range: $0.range, inserted: $0.inserted) }
            if let edit {
                document.journal.record(ByteEdit(edit))
            }
            document.text = view.string
            document.undo.note(pending.flatMap { UndoEdit.inverse(replacing: $0.range, with: $0.inserted, in: $0.before) })
            document.undo.close()
            document.isDirty = true
            state.noteEdit(view, in: document.id)
            host?.syncGutter()
            publishCursor(view)
            if let pending, let edit {
                shift(view, pending: pending, edit: edit)
            }
            if let typed {
                assist(view, pending: typed)
            } else {
                CompletionSession.shared.reset()
            }
            BracketHighlight.update(document: document, view: view)
            state.previewTextChanged(document, text: view.string)
            state.scheduleAutoSave(document)
            state.scheduleLiveCheck(document, view: view)
        }

        private func replayedEdit(_ view: RideTextView) -> PendingEdit? {
            let before = document.text
            guard let edit = TextDiff.minimalEdit(from: before, to: view.string) else {
                return nil
            }
            return PendingEdit(range: edit.range, inserted: edit.text, before: before)
        }

        private func shift(_ view: RideTextView, pending: PendingEdit, edit: InputEditFfi) {
            let released = view.folds.textChanged(range: pending.range, insertedLength: pending.inserted.utf16.count)
            view.refreshFragments(in: released)
            Underlines.shift(document: document, replacing: pending.range, with: pending.inserted.utf16.count)
            HighlightShift.apply(document: document, edit: ByteEdit(edit))
            shiftBreakpoints(pending)
            SessionService.shared.applyEdit(document: document, view: view, edit: edit, inserted: pending.inserted)
        }

        private func shiftBreakpoints(_ pending: PendingEdit) {
            guard let path = document.fileURL?.standardizedFileURL.path else {
                return
            }
            let edit = BreakpointShift.lineEdit(
                before: pending.before,
                range: pending.range,
                inserted: pending.inserted
            )
            if DebugController.shared.breakpoints.shift(path: path, edit: edit) {
                state.breakpointsChanged(path: path)
            }
        }

        private func assist(_ view: RideTextView, pending: PendingEdit) {
            let session = CompletionSession.shared
            session.textChanged(document: document, view: view, state: state, range: pending.range, inserted: pending.inserted)
            if session.editSource == .user {
                if state.prefs.signatureHelp {
                    SignatureHelpController.shared.textChanged(document: document, view: view, inserted: pending.inserted)
                }
                CheatSheetController.shared.textChanged(document: document, view: view)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            if let view = notification.object as? RideTextView {
                let caret = view.selectedRange()
                if caret.length == 0, view.folds.clampCaret(caret.location) != caret.location {
                    view.setSelectedRange(NSRange(location: view.folds.clampCaret(caret.location), length: 0))
                    return
                }
                BracketHighlight.update(document: document, view: view)
                publishCursor(view)
                CompletionSession.shared.selectionChanged(view: view)
                AIInlineController.shared.caretMoved(in: view)
                SignatureHelpController.shared.caretMoved(document: document, view: view)
                CheatSheetController.shared.caretMoved(view: view)
                IntentionGutter.shared.caretMoved(document: document, view: view)
                HierarchyFollower.shared.caretMoved(document: document, view: view, state: state)
                host?.docsCaretMoved()
            }
        }

        func publishCursor(_ view: NSTextView) {
            let loc = view.selectedRange().location
            guard let ride = view as? RideTextView else {
                return
            }
            let index = ride.lineIndex()
            let line = index.line(at: loc)
            let column = index.column(at: loc)
            document.caretByte = UInt32(Utf16.utf8Offset(in: ride.string, utf16: loc))
            if document.id == state.activeID, state.cursorLine != line || state.cursorColumn != column {
                if inViewUpdate {
                    DispatchQueue.main.async { [weak self, weak ride] in
                        if let self, let ride {
                            self.publishCursor(ride)
                        }
                    }
                } else {
                    if state.cursorLine != line {
                        state.cursorLine = line
                    }
                    if state.cursorColumn != column {
                        state.cursorColumn = column
                    }
                }
            }
            state.scheduleWorkspaceSave()
        }

        func viewportChanged() {
            guard let view = textView else {
                return
            }
            document.scrollLine = UInt32(max(1, view.firstVisibleLine()))
            SessionService.shared.setVisible(document: document, view: view)
            CompletionSession.shared.viewportChanged(view: view)
            CheatSheetController.shared.viewportChanged(view: view)
            SignatureHelpController.shared.relocate(in: view)
            HoverController.shared.hide()
            state.previewViewport(line: view.firstVisibleLine())
            state.scheduleWorkspaceSave()
        }
    }
}
