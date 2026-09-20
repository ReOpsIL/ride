import AppKit

final class BufferUndo {
    let manager = UndoStep.manager()
    private unowned let document: BufferDocument
    private var snapshot: String?
    private var owned = 0
    private var batching = false
    private var run: UndoRecord?

    init(document: BufferDocument) {
        self.document = document
    }

    private var isReverting: Bool {
        manager.isUndoing || manager.isRedoing
    }

    func open() {
        if snapshot == nil {
            snapshot = document.text
        }
        guard isReverting else {
            UndoStep.open(manager)
            return
        }
        guard manager.groupingLevel == 0 else {
            return
        }
        manager.beginUndoGrouping()
        owned += 1
    }

    func close() {
        guard !batching else {
            return
        }
        if let before = snapshot {
            snapshot = nil
            register(before: before)
        } else {
            run = nil
        }
        while owned > 0 {
            manager.endUndoGrouping()
            owned -= 1
        }
        UndoStep.close(manager)
    }

    func batch(_ body: () -> Void) {
        close()
        open()
        batching = true
        body()
        batching = false
        close()
    }

    private func register(before: String) {
        guard let edit = UndoEdit.inverse(before: before, after: document.text) else {
            return
        }
        if !isReverting, run?.extend(by: edit) == true {
            return
        }
        let record = UndoRecord(document: document, edit: edit)
        manager.registerUndo(withTarget: document) { _ in
            record.revert()
        }
        run = !isReverting && record.isTyping ? record : nil
    }
}
