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
        sessionId: UInt64,
        path: String?,
        text: String,
        caret: Int,
        qos: DispatchQoS.QoSClass = .userInitiated,
        then done: @escaping ([Intention]) -> Void
    ) -> Bool {
        let byte = UInt32(Utf16.utf8Offset(in: text, utf16: caret))
        let items = diagnostics(for: path)
        return RideEngineClient.shared.withEngine(qos: qos, { engine in
            engine.intentions(sessionId: sessionId, cursorByte: byte, diagnostics: items)
        }, then: done)
    }

    static func apply(_ intention: Intention, to view: RideTextView) {
        let text = view.string
        let changes = intention.edits.map { edit in
            TextChange(
                range: Utf16.nsRange(in: text, startByte: edit.startByte, endByte: edit.endByte),
                text: edit.text
            )
        }
        let applied = EditResult.applying(changes, to: text)
        let caretByte = Int(intention.edits.last?.caretByte ?? 0)
        let caret = Utf16.utf16Offset(in: applied, utf8: caretByte)
        EditorCommand.apply(
            EditResult(changes: changes, selection: NSRange(location: caret, length: 0)),
            to: view
        )
    }

    static func apply(fix: StoredFix, to view: RideTextView) {
        let intention = Intention(id: 0, title: fix.title, edits: fix.edits.map(CheckConvert.ffi))
        apply(intention, to: view)
    }
}
