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
        if allowFormat, prefs.formatOnSave, buffer.id == activeID, formatsOnSave(buffer.language) {
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

    private func formatsOnSave(_ language: BufferLanguage) -> Bool {
        switch language {
        case .rust: return true
        case .c, .cpp: return RideEngineClient.shared.engine?.hasTool(name: "clang-format") ?? false
        case .toml, .make, .cmake, .markdown, .plain: return false
        }
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
        let language = buffer.language
        let path = buffer.fileURL?.path
        let id = buffer.id
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                switch language {
                case .c, .cpp: try engine.formatC(text: text, assumeFilename: path)
                default: try engine.formatRust(text: text, edition: edition)
                }
            }
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
                formatError = message.split(separator: "\n").first.map(String.init) ?? "format failed"
            } else {
                formatError = "\(error)"
            }
        }
    }
}
