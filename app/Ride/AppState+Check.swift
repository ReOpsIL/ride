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
        formatNow(thenSave: thenSave, startByte: nil, endByte: nil)
    }

    func formatSelection() {
        let text = EditorJump.shared.view?.string ?? activeBuffer?.text ?? ""
        let sel = EditorJump.shared.view?.selectedRange() ?? NSRange(location: 0, length: 0)
        let start = UInt32(Utf16.utf8Offset(in: text, utf16: sel.location))
        let end = UInt32(Utf16.utf8Offset(in: text, utf16: NSMaxRange(sel)))
        formatNow(thenSave: false, startByte: start, endByte: end)
    }

    private func formatNow(thenSave: Bool, startByte: UInt32?, endByte: UInt32?) {
        guard let buffer = activeBuffer, !buffer.isReadOnly, let engine = RideEngineClient.shared.engine else {
            return
        }
        if let view = EditorJump.shared.view {
            buffer.text = view.string
        }
        let text = buffer.text
        let edition = workspaceRoot.flatMap(cargoEdition)
        let path = buffer.fileURL?.path ?? "untitled.\(buffer.language.fileExtension)"
        let language = buffer.language
        let id = buffer.id
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                try Self.invokeFormat(
                    engine: engine,
                    language: language,
                    path: path,
                    text: text,
                    edition: edition,
                    startByte: startByte,
                    endByte: endByte
                )
            }
            DispatchQueue.main.async {
                self?.formatFinished(result, bufferID: id, thenSave: thenSave)
            }
        }
    }

    private static func invokeFormat(
        engine: Engine,
        language: BufferLanguage,
        path: String,
        text: String,
        edition: String?,
        startByte: UInt32?,
        endByte: UInt32?
    ) throws -> String {
        if let startByte, let endByte {
            switch language {
            case .c, .cpp:
                return try engine.formatC(
                    text: text,
                    assumeFilename: path,
                    startByte: startByte,
                    endByte: endByte
                )
            case .rust:
                return try engine.formatRust(
                    text: text,
                    edition: edition,
                    startByte: startByte,
                    endByte: endByte
                )
            default:
                break
            }
        }
        return try engine.formatBuffer(path: path, text: text, edition: edition)
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
