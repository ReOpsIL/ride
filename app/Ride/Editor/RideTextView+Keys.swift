import AppKit

extension RideTextView {
    override func insertTab(_ sender: Any?) {
        if CompletionSession.shared.popup.accept() {
            return
        }
        insertText(String(repeating: " ", count: tabWidth), replacementRange: selectedRange())
    }

    override func insertNewline(_ sender: Any?) {
        if CompletionSession.shared.popup.accept() {
            return
        }
        super.insertNewline(sender)
    }

    override func cancelOperation(_ sender: Any?) {
        if CompletionSession.shared.isVisible {
            CompletionSession.shared.hide()
            return
        }
        super.cancelOperation(sender)
    }

    override func keyDown(with event: NSEvent) {
        if CompletionSession.shared.isVisible {
            switch event.keyCode {
            case 126:
                CompletionSession.shared.popup.move(-1)
                return
            case 125:
                CompletionSession.shared.popup.move(1)
                return
            case 53:
                CompletionSession.shared.hide()
                return
            case 36, 76, 48:
                if CompletionSession.shared.popup.accept() {
                    return
                }
            default:
                break
            }
        }
        super.keyDown(with: event)
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
