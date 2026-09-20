import AppKit

extension RideTextView {
    func replaceText(in range: NSRange, with text: String) {
        guard shouldChangeText(in: range, replacementString: text) else {
            return
        }
        textStorage?.replaceCharacters(in: range, with: text)
        didChangeText()
    }

    func applyChanges(_ changes: [TextChange]) {
        breakUndoCoalescing()
        UndoStep.perform(undoManager) {
            for change in changes.reversed() {
                replaceText(in: change.range, with: change.text)
            }
        }
        breakUndoCoalescing()
    }

    override func breakUndoCoalescing() {
        super.breakUndoCoalescing()
        UndoStep.close(undoManager)
    }
}
