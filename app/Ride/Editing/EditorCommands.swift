import AppKit

struct EditorTarget {
    let view: RideTextView
    let document: BufferDocument
    let state: AppState
    let text: String
    let selection: NSRange

    var unit: String {
        EditorCommand.indentUnit(for: view, language: document.language)
    }

    var tokens: CommentTokens {
        CommentTokens.tokens(for: document.language)
    }

    var caretByte: UInt32 {
        UInt32(Utf16.utf8Offset(in: text, utf16: selection.location))
    }

    var selectionEndByte: UInt32 {
        UInt32(Utf16.utf8Offset(in: text, utf16: NSMaxRange(selection)))
    }

    func session<T>(_ work: (Engine, UInt64) -> T?) -> T? {
        SessionService.shared.readNow(document, work) ?? nil
    }
}

enum EditorCommands {
    static func target(editing: Bool = true) -> EditorTarget? {
        guard let view = EditorPanes.shared.focusedView, view.window?.firstResponder === view, view.isEditable || !editing,
              let binding = view.hooks.binding?()
        else {
            return nil
        }
        return EditorTarget(view: view, document: binding.document, state: binding.state, text: view.string, selection: view.selectedRange())
    }

    static func run(editing: Bool = true, _ transform: (EditorTarget) -> EditResult) {
        guard let target = target(editing: editing) else {
            return
        }
        EditorCommand.apply(transform(target), to: target.view)
    }

    static func indent() {
        run { LineOps.indent($0.text, selection: $0.selection, unit: $0.unit) }
    }

    static func unindent() {
        run { LineOps.unindent($0.text, selection: $0.selection, width: $0.view.tabWidth) }
    }

    static func duplicate() {
        run { LineOps.duplicate($0.text, selection: $0.selection) }
    }

    static func deleteLines() {
        run { LineOps.deleteLines($0.text, selection: $0.selection) }
    }

    static func joinLines() {
        run { LineOps.joinLines($0.text, selection: $0.selection) }
    }

    static func moveLines(up: Bool) {
        run { LineOps.moveLines($0.text, selection: $0.selection, up: up) }
    }

    static func moveStatement(up: Bool) {
        guard let target = target(),
              let bounds = target.session({ $0.statementBounds(sessionId: $1, byte: target.caretByte) }),
              let other = up ? bounds.previous : bounds.next
        else {
            return
        }
        let map = Utf16Map(target.text)
        let result = LineOps.moveStatement(
            target.text,
            current: map.nsRange(startByte: bounds.current.startByte, endByte: bounds.current.endByte),
            other: map.nsRange(startByte: other.startByte, endByte: other.endByte),
            selection: target.selection
        )
        EditorCommand.apply(result, to: target.view)
    }

    static func completeStatement() {
        guard let target = target(), let edit = target.session({ $0.completeStatement(sessionId: $1, byte: target.caretByte) }) else {
            return
        }
        EditorCommand.apply(TextEditApply.result([edit], caret: edit, in: target.text), to: target.view)
    }

    static func applyGenerator(_ kind: GenKind) {
        guard let target = target(),
              let edit = target.session({ $0.generateApply(sessionId: $1, cursorByte: target.caretByte, kind: kind) })
        else {
            return
        }
        EditorCommand.apply(TextEditApply.result([edit], caret: edit, in: target.text), to: target.view)
    }

    static func newLine(before: Bool) {
        run { target in
            let ns = target.text as NSString
            let indent = LineSpan.indentation(ns, line: LineSpan.lineRange(ns, NSRange(location: target.selection.location, length: 0)))
            return before
                ? LineOps.newLineBefore(target.text, caret: target.selection.location, indent: indent)
                : LineOps.newLineAfter(target.text, caret: target.selection.location, indent: indent)
        }
    }

    static func toggleCase() {
        run { LineOps.toggleCase($0.text, selection: $0.selection) }
    }

    static func sortLines() {
        run { LineOps.sortLines($0.text, selection: $0.selection) }
    }

    static func autoIndent() {
        run { SmartIndent.autoIndent($0.text, selection: $0.selection, unit: $0.unit) }
    }

    static func commentLine() {
        run { CommentToggle.toggleLine($0.text, selection: $0.selection, tokens: $0.tokens) }
    }

    static func commentBlock() {
        run { CommentToggle.toggleBlock($0.text, selection: $0.selection, tokens: $0.tokens) }
    }

    static func triggerCompletion() {
        guard let view = EditorPanes.shared.focusedView else {
            return
        }
        CompletionSession.shared.trigger(view: view)
    }

    static func toggleCheatSheet() {
        guard let view = EditorPanes.shared.focusedView else {
            return
        }
        CheatSheetController.shared.toggle(view: view)
    }
}
