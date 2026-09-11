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
}

enum EditorCommands {
    static func target() -> EditorTarget? {
        guard let view = EditorPanes.shared.focusedView, view.window?.firstResponder === view, view.isEditable,
              let binding = view.hooks.binding?()
        else {
            return nil
        }
        return EditorTarget(view: view, document: binding.document, state: binding.state, text: view.string, selection: view.selectedRange())
    }

    static func run(_ transform: (EditorTarget) -> EditResult) {
        guard let target = target() else {
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
