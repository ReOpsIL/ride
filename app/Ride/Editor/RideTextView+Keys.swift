import AppKit

extension RideTextView {
    override func insertTab(_ sender: Any?) {
        if CompletionSession.shared.accept() || CompletionSession.shared.snippetNext() || indentSelection(unindent: false) {
            return
        }
        let unit = hooks.binding?()?.document.language == .make ? "\t" : String(repeating: " ", count: tabWidth)
        super.insertText(unit, replacementRange: selectedRange())
    }

    override func insertBacktab(_ sender: Any?) {
        if CompletionSession.shared.snippetPrevious() || indentSelection(unindent: true) {
            return
        }
        super.insertBacktab(sender)
    }

    override func insertNewline(_ sender: Any?) {
        if CompletionSession.shared.accept() {
            return
        }
        SignatureHelpController.shared.hide()
        if smartNewline() {
            return
        }
        super.insertNewline(sender)
    }

    override func cancelOperation(_ sender: Any?) {
        if CompletionSession.shared.isVisible || CheatSheetController.shared.isVisible {
            CompletionSession.shared.hide()
            CheatSheetController.shared.close()
            return
        }
        if SignatureHelpController.shared.isVisible {
            SignatureHelpController.shared.hide()
            return
        }
        if let docs = EditorPanes.shared.host(for: self)?.docs, docs.isVisible {
            docs.hide()
            return
        }
        if CompletionSession.shared.endSnippet() {
            return
        }
        super.cancelOperation(sender)
    }

    override func keyDown(with event: NSEvent) {
        HoverController.shared.hide()
        EditorPanes.shared.host(for: self)?.hideUnpinnedDocs()
        if event.keyCode == 49, event.modifierFlags.contains(.control) {
            if event.modifierFlags.contains(.shift) {
                CheatSheetController.shared.toggle(view: self)
            } else {
                CompletionSession.shared.trigger(view: self)
            }
            return
        }
        if CheatSheetController.shared.isVisible, handleCheatSheetKey(event) {
            return
        }
        if CompletionSession.shared.isVisible, handleCompletionKey(event) {
            return
        }
        super.keyDown(with: event)
    }

    private func handleCheatSheetKey(_ event: NSEvent) -> Bool {
        let sheet = CheatSheetController.shared
        let shared = CompletionSession.shared.isVisible
        let takes = !shared || sheet.focused || event.modifierFlags.contains(.option)
        guard takes else {
            return event.keyCode == 53 && cancelPopups()
        }
        switch event.keyCode {
        case 126:
            sheet.move(-1)
            return true
        case 125:
            sheet.move(1)
            return true
        case 53:
            return cancelPopups()
        case 36, 76:
            return sheet.insert()
        case 48:
            return sheet.insert()
        default:
            return false
        }
    }

    private func cancelPopups() -> Bool {
        CompletionSession.shared.hide()
        CheatSheetController.shared.close()
        return true
    }

    private func handleCompletionKey(_ event: NSEvent) -> Bool {
        let popup = CompletionSession.shared.popup
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "i" {
            DocController.showCompletion(in: self)
            return true
        }
        switch event.keyCode {
        case 126:
            popup.move(-1)
            return true
        case 125:
            popup.move(1)
            return true
        case 53:
            CompletionSession.shared.hide()
            return true
        case 36, 76, 48:
            return CompletionSession.shared.accept()
        default:
            return false
        }
    }

    override func doCommand(by selector: Selector) {
        if CheatSheetController.shared.isVisible, !CompletionSession.shared.isVisible || CheatSheetController.shared.focused {
            if selector == #selector(moveUp(_:)) {
                CheatSheetController.shared.move(-1)
                return
            }
            if selector == #selector(moveDown(_:)) {
                CheatSheetController.shared.move(1)
                return
            }
        }
        if CompletionSession.shared.isVisible {
            if selector == #selector(moveUp(_:)) {
                CompletionSession.shared.popup.move(-1)
                return
            }
            if selector == #selector(moveDown(_:)) {
                CompletionSession.shared.popup.move(1)
                return
            }
        }
        super.doCommand(by: selector)
    }
}
