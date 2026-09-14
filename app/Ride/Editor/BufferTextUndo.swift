import Foundation

protocol TextUndoTarget: AnyObject {
    var undoText: String { get set }
}

enum BufferTextUndo {
    static func apply<T: TextUndoTarget>(
        _ text: String,
        to target: T,
        undo manager: UndoManager?,
        commit: @escaping (T) -> Void
    ) {
        let previous = target.undoText
        guard previous != text else {
            return
        }
        target.undoText = text
        commit(target)
        guard let manager else {
            return
        }
        manager.beginUndoGrouping()
        manager.registerUndo(withTarget: target) { restored in
            apply(previous, to: restored, undo: manager, commit: commit)
        }
        manager.endUndoGrouping()
    }
}
