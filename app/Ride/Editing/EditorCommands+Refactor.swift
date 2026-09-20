import AppKit

extension EditorCommands {
    static func extractVariable() {
        refactor(notice: "Select an expression to extract") { engine, id, target, text in
            engine.extractVariable(
                sessionId: id,
                startByte: selectionStart(target, text),
                endByte: selectionEnd(target, text)
            )
        }
    }

    static func introduceConstant() {
        refactor(notice: "Select a literal to introduce") { engine, id, target, text in
            engine.introduceConstant(
                sessionId: id,
                startByte: selectionStart(target, text),
                endByte: selectionEnd(target, text)
            )
        }
    }

    static func inlineVariable() {
        refactor(notice: "Place the caret on a local variable to inline") { engine, id, target, text in
            engine.inlineVariable(sessionId: id, cursorByte: selectionStart(target, text))
        }
    }

    private static func selectionStart(_ target: EditorTarget, _ text: String) -> UInt32 {
        UInt32(Utf16.utf8Offset(in: text, utf16: target.selection.location))
    }

    private static func selectionEnd(_ target: EditorTarget, _ text: String) -> UInt32 {
        UInt32(Utf16.utf8Offset(in: text, utf16: NSMaxRange(target.selection)))
    }

    private static func refactor(
        notice: String,
        plan make: (Engine, UInt64, EditorTarget, String) -> ExtractPlan?
    ) {
        guard let target = target(), let id = target.document.sessionId, let engine = RideEngineClient.shared.engine else {
            return
        }
        let text = target.text
        guard let plan = make(engine, id, target, text) else {
            target.state.showNotice(notice)
            return
        }
        apply(plan, text: text, to: target.view)
    }

    private static func apply(_ plan: ExtractPlan, text: String, to view: RideTextView) {
        let changes = plan.edits.map { edit in
            TextChange(range: Utf16.nsRange(in: text, startByte: edit.startByte, endByte: edit.endByte), text: edit.text)
        }
        let applied = EditResult.applying(changes, to: text)
        let from = Utf16.utf16Offset(in: applied, utf8: Int(plan.selectStart))
        let to = Utf16.utf16Offset(in: applied, utf8: Int(plan.selectEnd))
        let selection = NSRange(location: from, length: max(0, to - from))
        EditorCommand.apply(EditResult(changes: changes, selection: selection), to: view)
    }
}
