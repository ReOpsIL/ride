import AppKit

extension RideTextView {
    override func insertTab(_ sender: Any?) {
        if CompletionSession.shared.accept() || CompletionSession.shared.snippetNext() {
            return
        }
        insertText(String(repeating: " ", count: tabWidth), replacementRange: selectedRange())
    }

    override func insertBacktab(_ sender: Any?) {
        if CompletionSession.shared.snippetPrevious() {
            return
        }
        super.insertBacktab(sender)
    }

    override func insertNewline(_ sender: Any?) {
        if CompletionSession.shared.accept() {
            return
        }
        SignatureHelpController.shared.hide()
        super.insertNewline(sender)
    }

    override func cancelOperation(_ sender: Any?) {
        if CompletionSession.shared.isVisible {
            CompletionSession.shared.hide()
            return
        }
        if SignatureHelpController.shared.isVisible {
            SignatureHelpController.shared.hide()
            return
        }
        if CompletionSession.shared.endSnippet() {
            return
        }
        super.cancelOperation(sender)
    }

    override func keyDown(with event: NSEvent) {
        HoverController.shared.hide()
        if event.keyCode == 49, event.modifierFlags.contains(.control) {
            CompletionSession.shared.trigger(view: self)
            return
        }
        if CompletionSession.shared.isVisible, handleCompletionKey(event) {
            return
        }
        super.keyDown(with: event)
    }

    private func handleCompletionKey(_ event: NSEvent) -> Bool {
        let popup = CompletionSession.shared.popup
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "i" {
            popup.toggleWideDoc()
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
