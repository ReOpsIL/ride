import AppKit

extension RideTextView {
    var typingTarget: EditorTarget? {
        guard let binding = hooks.binding?() else {
            return nil
        }
        return EditorTarget(view: self, document: binding.document, state: binding.state, text: string, selection: selectedRange())
    }

    func smartNewline() -> Bool {
        guard let target = typingTarget, target.selection.length == 0 else {
            return false
        }
        let comment = target.tokens.line == "#" ? "#" : nil
        let result = SmartIndent.newline(target.text, caret: target.selection.location, unit: target.unit, lineComment: comment)
        guard !result.changes.isEmpty else {
            return false
        }
        applyTyping(result)
        return true
    }

    func indentSelection(unindent: Bool) -> Bool {
        guard let target = typingTarget else {
            return false
        }
        let ns = target.text as NSString
        let spansLines = ns.substring(with: target.selection).contains("\n")
        guard unindent || spansLines else {
            return false
        }
        let result = unindent
            ? LineOps.unindent(target.text, selection: target.selection, width: tabWidth)
            : LineOps.indent(target.text, selection: target.selection, unit: target.unit)
        applyTyping(result)
        return true
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        guard let typed = string as? String, typed.count == 1, replacementRange.location == NSNotFound,
              let target = typingTarget, CompletionSession.shared.editSource == .user
        else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }
        if target.selection.length == 0, let dedent = SmartIndent.closingBrace(target.text, caret: target.selection.location, typed: typed) {
            applyTyping(dedent, keepCompletion: false)
            return
        }
        switch BracketPairing.onType(typed, text: target.text, selection: target.selection, language: target.document.language) {
        case let .insertPair(close):
            super.insertText(typed + close, replacementRange: replacementRange)
            setSelectedRange(NSRange(location: target.selection.location + (typed as NSString).length, length: 0))
        case .typeOver:
            setSelectedRange(NSRange(location: target.selection.location + 1, length: 0))
        case let .wrap(open, close):
            let selected = (target.text as NSString).substring(with: target.selection)
            super.insertText(open + selected + close, replacementRange: target.selection)
            setSelectedRange(NSRange(location: target.selection.location + (open as NSString).length, length: (selected as NSString).length))
        case .none:
            super.insertText(string, replacementRange: replacementRange)
        }
    }

    override func deleteBackward(_ sender: Any?) {
        let caret = selectedRange()
        if caret.length == 0, BracketPairing.deletesPair(string, caret: caret.location) {
            replaceText(in: NSRange(location: caret.location - 1, length: 2), with: "")
            setSelectedRange(NSRange(location: caret.location - 1, length: 0))
            return
        }
        super.deleteBackward(sender)
    }

    private func applyTyping(_ result: EditResult, keepCompletion: Bool = true) {
        if !keepCompletion {
            CompletionSession.shared.hide()
        }
        let session = CompletionSession.shared
        undoManager?.beginUndoGrouping()
        for change in result.changes.reversed() {
            replaceText(in: change.range, with: change.text)
        }
        undoManager?.endUndoGrouping()
        _ = session
        let length = (string as NSString).length
        let location = min(max(result.selection.location, 0), length)
        setSelectedRange(NSRange(location: location, length: min(max(result.selection.length, 0), length - location)))
    }
}
