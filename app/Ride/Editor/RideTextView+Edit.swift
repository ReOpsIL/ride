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
        guard let undoSteps else {
            applyEach(changes)
            return
        }
        undoSteps.batch {
            applyEach(changes)
        }
    }

    private func applyEach(_ changes: [TextChange]) {
        for change in changes.reversed() {
            replaceText(in: change.range, with: change.text)
        }
    }

    override func breakUndoCoalescing() {
        super.breakUndoCoalescing()
        undoSteps?.close()
    }
}
