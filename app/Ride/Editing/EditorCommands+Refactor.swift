import AppKit

extension EditorCommands {
    static func extractVariable() {
        guard let target = target(), let id = target.document.sessionId, let engine = RideEngineClient.shared.engine else {
            return
        }
        let text = target.text
        let start = UInt32(Utf16.utf8Offset(in: text, utf16: target.selection.location))
        let end = UInt32(Utf16.utf8Offset(in: text, utf16: NSMaxRange(target.selection)))
        guard let plan = engine.extractVariable(sessionId: id, startByte: start, endByte: end) else {
            target.state.showNotice("Select an expression to extract")
            return
        }
        let changes = plan.edits.map { edit in
            TextChange(range: Utf16.nsRange(in: text, startByte: edit.startByte, endByte: edit.endByte), text: edit.text)
        }
        let applied = EditResult.applying(changes, to: text)
        let from = Utf16.utf16Offset(in: applied, utf8: Int(plan.selectStart))
        let to = Utf16.utf16Offset(in: applied, utf8: Int(plan.selectEnd))
        let selection = NSRange(location: from, length: max(0, to - from))
        EditorCommand.apply(EditResult(changes: changes, selection: selection), to: target.view)
    }
}
