import AppKit

extension RideTextView {
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(undo(_:)):
            return undoSteps.map { $0.manager.canUndo } ?? super.validateUserInterfaceItem(item)
        case #selector(redo(_:)):
            return undoSteps.map { $0.manager.canRedo } ?? super.validateUserInterfaceItem(item)
        case #selector(copy(_:)):
            return selectedRange().length == 0 ? !string.isEmpty : super.validateUserInterfaceItem(item)
        case #selector(cut(_:)):
            return selectedRange().length == 0 ? isEditable && !string.isEmpty : super.validateUserInterfaceItem(item)
        default:
            return super.validateUserInterfaceItem(item)
        }
    }
}
