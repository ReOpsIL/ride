import AppKit

extension RideTextView {
    override var undoManager: UndoManager? {
        nil
    }

    @objc func undo(_ sender: Any?) {
        undoSteps?.manager.undo()
    }

    @objc func redo(_ sender: Any?) {
        undoSteps?.manager.redo()
    }
}
