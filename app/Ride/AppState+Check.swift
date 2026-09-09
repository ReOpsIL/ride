import AppKit

extension AppState {
    func runCheck() {
        guard let root = workspaceRoot else {
            return
        }
        CheckService.shared.run(root: root)
    }

    func didSave(_ buffer: BufferDocument, allowFormat: Bool = true) {
        if allowFormat, prefs.formatOnSave, buffer.fileURL?.pathExtension == "rs", buffer.id == activeID {
            formatActive(thenSave: true)
        }
        guard let root = workspaceRoot, prefs.checkOnSave else {
            return
        }
        CheckService.shared.schedule(root: root)
    }

    func checkFinished(_ diagnostics: [Diagnostic]) {
        if diagnostics.contains(where: { $0.level == .error }) {
            showProblems = true
        }
        if let view = EditorJump.shared.view, let buffer = activeBuffer {
            DiagnosticUnderlines.apply(document: buffer, view: view)
        }
    }

    func toggleProblems() {
        showProblems.toggle()
    }

    func openDiagnostic(_ diag: Diagnostic) {
        let url = URL(fileURLWithPath: diag.path).standardizedFileURL
        pendingJump = diag.byteStart
        openFile(url, readOnly: !WorkspaceFS.contains(root: workspaceRoot, file: url))
    }

    func formatActive(thenSave: Bool = false) {
        guard let buffer = activeBuffer, !buffer.isReadOnly, let engine = RideEngineClient.shared.engine else {
            return
        }
        if let view = EditorJump.shared.view {
            buffer.text = view.string
        }
        let text = buffer.text
        let edition = workspaceRoot.flatMap(cargoEdition)
        let id = buffer.id
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try engine.formatRust(text: text, edition: edition) }
            DispatchQueue.main.async {
                self?.formatFinished(result, bufferID: id, thenSave: thenSave)
            }
        }
    }

    private func formatFinished(_ result: Result<String, Error>, bufferID: UUID, thenSave: Bool) {
        guard activeID == bufferID, let buffer = activeBuffer else {
            return
        }
        switch result {
        case .success(let formatted):
            formatError = nil
            guard formatted != buffer.text else {
                return
            }
            applyText = formatted
            applyThenSave = thenSave
            objectWillChange.send()
        case .failure(let error):
            if case let EngineError.Tool(message) = error {
                formatError = message.split(separator: "\n").first.map(String.init) ?? "rustfmt failed"
            } else {
                formatError = "\(error)"
            }
        }
    }
}
