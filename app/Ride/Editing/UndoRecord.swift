import AppKit

final class UndoRecord {
    private unowned let document: BufferDocument
    private var edit: UndoEdit

    init(document: BufferDocument, edit: UndoEdit) {
        self.document = document
        self.edit = edit
    }

    var isTyping: Bool {
        edit.isTyping
    }

    func extend(by next: UndoEdit) -> Bool {
        guard let merged = edit.extended(by: next) else {
            return false
        }
        edit = merged
        return true
    }

    func revert() {
        guard let view = EditorPanes.shared.host(bound: document)?.textView else {
            return
        }
        guard NSMaxRange(edit.range) <= (view.string as NSString).length else {
            return
        }
        view.replaceText(in: edit.range, with: edit.text)
        view.setSelectedRange(NSRange(location: edit.caret, length: 0))
        view.scrollRangeToVisible(view.selectedRange())
    }
}
