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

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        guard let manager = undoSteps?.manager else {
            return super.validateUserInterfaceItem(item)
        }
        switch item.action {
        case #selector(undo(_:)):
            return manager.canUndo
        case #selector(redo(_:)):
            return manager.canRedo
        default:
            return super.validateUserInterfaceItem(item)
        }
    }
}
