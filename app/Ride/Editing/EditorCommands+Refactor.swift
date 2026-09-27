import AppKit

extension EditorCommands {
    static func extractVariable() {
        refactor(notice: "Select an expression to extract") { engine, id, target in
            engine.extractVariable(sessionId: id, startByte: target.caretByte, endByte: target.selectionEndByte)
        }
    }

    static func introduceConstant() {
        refactor(notice: "Select a literal to introduce") { engine, id, target in
            engine.introduceConstant(sessionId: id, startByte: target.caretByte, endByte: target.selectionEndByte)
        }
    }

    static func inlineVariable() {
        refactor(notice: "Place the caret on a local variable to inline") { engine, id, target in
            engine.inlineVariable(sessionId: id, cursorByte: target.caretByte)
        }
    }

    private static func refactor(
        notice: String,
        plan make: (Engine, UInt64, EditorTarget) -> ExtractPlan?
    ) {
        guard let target = target() else {
            return
        }
        guard let plan = target.session({ make($0, $1, target) }) else {
            target.state.showNotice(notice)
            return
        }
        apply(plan, text: target.text, to: target.view)
    }

    private static func apply(_ plan: ExtractPlan, text: String, to view: RideTextView) {
        let changes = TextEditApply.changes(plan.edits, in: text)
        let applied = Utf16Map(EditResult.applying(changes, to: text))
        let from = applied.utf16(byte: Int(plan.selectStart))
        let to = applied.utf16(byte: Int(plan.selectEnd))
        let selection = NSRange(location: from, length: max(0, to - from))
        EditorCommand.apply(EditResult(changes: changes, selection: selection), to: view)
    }
}
