import AppKit

enum IntentionActions {
    static func diagnostics(for path: String?) -> [Diagnostic] {
        guard let path else {
            return []
        }
        return CheckService.shared.diagnostics.filter {
            URL(fileURLWithPath: $0.path).standardizedFileURL.path == path
        }
    }

    @discardableResult
    static func fetch(
        document: BufferDocument,
        text: String,
        caret: Int,
        qos: DispatchQoS.QoSClass = .userInitiated,
        then done: @escaping ([Intention]) -> Void
    ) -> Bool {
        let byte = UInt32(Utf16.utf8Offset(in: text, utf16: caret))
        let items = diagnostics(for: document.fileURL?.standardizedFileURL.path)
        return SessionService.shared.read(document, delivery: .currentText, qos: qos, { engine, id in
            engine.intentions(sessionId: id, cursorByte: byte, diagnostics: items)
        }, then: done)
    }

    static func apply(_ intention: Intention, to view: RideTextView) {
        guard let caret = intention.edits.last else {
            return
        }
        EditorCommand.apply(TextEditApply.result(intention.edits, caret: caret, in: view.string), to: view)
    }

    static func apply(fix: StoredFix, to view: RideTextView) {
        let intention = Intention(id: 0, title: fix.title, edits: fix.edits.map(CheckConvert.ffi))
        apply(intention, to: view)
    }
}
