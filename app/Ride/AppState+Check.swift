import AppKit

extension AppState {
    func runCheck() {
        if let buffer = activeBuffer, buffer.language.usesClang, let url = buffer.fileURL {
            CheckService.shared.run(file: url)
        } else if let root = workspaceRoot {
            CheckService.shared.run(root: root)
        }
    }

    func didSave(_ buffer: BufferDocument, allowFormat: Bool = true) {
        if allowFormat, prefs.formatOnSave, buffer.id == activeID, formatsOnSave(buffer) {
            formatActive(thenSave: true)
        }
        guard prefs.checkOnSave else {
            return
        }
        if buffer.language.usesClang, let url = buffer.fileURL {
            CheckService.shared.schedule(file: url)
        } else if let root = workspaceRoot {
            CheckService.shared.schedule(root: root)
        }
    }

    private func formatsOnSave(_ buffer: BufferDocument) -> Bool {
        guard let engine = RideEngineClient.shared.engine else {
            return false
        }
        return !engine.formatterName(path: buffer.fileURL?.path, text: buffer.text).isEmpty
    }

    func checkFinished(_ diagnostics: [Diagnostic]) {
        if diagnostics.contains(where: { $0.level == .error }) {
            showProblems = true
        }
        if let view = EditorJump.shared.view, let buffer = activeBuffer {
            Underlines.apply(document: buffer, view: view, parseErrors: nil)
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
        let path = buffer.fileURL?.path ?? "untitled.\(buffer.language.fileExtension)"
        let id = buffer.id
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try engine.formatBuffer(path: path, text: text, edition: edition) }
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
                showNotice("\(buffer.displayName) is already formatted", seconds: 2)
                return
            }
            applyText = formatted
            applyThenSave = thenSave
            objectWillChange.send()
        case .failure(let error):
            if case let EngineError.Tool(message) = error {
                formatError = message.split(separator: "\n").first.map(String.init) ?? "format failed"
            } else {
                formatError = "\(error)"
            }
            showNotice("Could not format \(buffer.displayName): \(formatError ?? "")")
        }
    }
}
