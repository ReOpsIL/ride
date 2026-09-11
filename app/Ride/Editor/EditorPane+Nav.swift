import AppKit

extension EditorPane.Coordinator {
    func installHooks(_ view: RideTextView) {
        view.hooks.goToDefinition = { [weak self] utf16 in
            guard let self else {
                return
            }
            self.state.goToDefinition(document: self.document, view: view, utf16: utf16)
        }
        view.hooks.definitions = { [weak self] utf16, done in
            guard let self else {
                return
            }
            Definitions.lookup(document: self.document, view: view, utf16: utf16, done: done)
        }
        view.hooks.binding = { [weak self] in
            self.map { EditorBinding(document: $0.document, state: $0.state) }
        }
    }

    func flush(_ host: EditorHostView) {
        if let text = state.applyText {
            state.applyText = nil
            applyText(text, host: host)
        }
        if let byte = state.pendingJump {
            state.pendingJump = nil
            host.jump(byte: byte)
            state.recordLocation()
        }
    }

    private func applyText(_ text: String, host: EditorHostView) {
        let view = host.textView
        let line = view.lineIndex().line(at: view.selectedRange().location)
        document.text = text
        host.replaceText(text)
        host.jump(toLine: line)
        SessionService.shared.resync(document: document, view: view)
        if state.applyThenSave {
            state.applyThenSave = false
            try? document.save(from: view)
            state.didSave(document, allowFormat: false)
        } else {
            document.isDirty = true
            state.scheduleAutoSave()
        }
    }
}
