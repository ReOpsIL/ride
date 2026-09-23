import AppKit

extension AppState {
    func runCheck() {
        if let buffer = activeBuffer, buffer.language.usesClang, let url = buffer.fileURL {
            CheckService.shared.run(file: url)
        } else if let root = activeProjectRoot {
            CheckService.shared.run(root: root)
        }
    }

    func runProjectCheck() {
        guard let root = activeProjectRoot else {
            return
        }
        CheckService.shared.runProject(root: root)
    }

    func didSave(_ buffer: BufferDocument, allowFormat: Bool = true) {
        if let id = buffer.sessionId {
            UsageIndexer.index(sessionId: id)
        }
        if allowFormat, prefs.formatOnSave, formatsOnSave(buffer) {
            formatNow(buffer, thenSave: true, startByte: nil, endByte: nil)
        }
        guard prefs.checkOnSave else {
            return
        }
        if buffer.language.usesClang, let url = buffer.fileURL {
            if ["h", "hpp"].contains(url.pathExtension.lowercased()) {
                CheckService.shared.scheduleIncluding(header: url)
            } else {
                CheckService.shared.schedule(file: url)
            }
            runClangTidyOnSave(buffer)
        } else if let root = projectRoot(for: buffer.fileURL) {
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
        refreshDiagnosticUnderlines()
    }

    func dropClosedClangDiagnostics(from previous: [BufferDocument]) {
        let open = Set(buffers.compactMap { $0.fileURL?.path })
        let closed = previous.compactMap { buffer -> String? in
            guard let path = buffer.fileURL?.path, !open.contains(path) else {
                return nil
            }
            return path
        }
        CheckService.shared.dropClang(paths: closed)
        if !closed.isEmpty {
            refreshDiagnosticUnderlines()
        }
    }

    func dropMissingClangDiagnostics() {
        let gone = CheckService.shared.clangPaths.filter { !FileManager.default.fileExists(atPath: $0) }
        CheckService.shared.dropClang(paths: gone)
        if !gone.isEmpty {
            refreshDiagnosticUnderlines()
        }
    }

    func toggleProblems() {
        showProblems.toggle()
    }

    func openDiagnostic(_ diag: Diagnostic) {
        jumpToDiagnostic(path: diag.path, byteStart: diag.byteStart)
    }

    func openDiagnostic(_ diag: StoredDiagnostic) {
        jumpToDiagnostic(path: diag.path, byteStart: diag.byteStart)
    }

    private func jumpToDiagnostic(path: String, byteStart: UInt32) {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        openFile(url, at: .byte(byteStart), readOnly: !WorkspaceFS.contains(root: workspaceRoot, file: url))
    }

    func refreshDiagnosticUnderlines() {
        for host in EditorPanes.shared.all {
            if let document = host.document {
                Underlines.apply(document: document, view: host.textView, parseErrors: nil)
            }
        }
    }

    func formatActive(thenSave: Bool = false) {
        guard let buffer = activeBuffer else {
            return
        }
        formatNow(buffer, thenSave: thenSave, startByte: nil, endByte: nil)
    }

    func formatSelection() {
        guard let buffer = activeBuffer, let host = EditorPanes.shared.host(bound: buffer) else {
            return
        }
        let text = host.textView.string
        let sel = host.textView.selectedRange()
        let start = UInt32(Utf16.utf8Offset(in: text, utf16: sel.location))
        let end = UInt32(Utf16.utf8Offset(in: text, utf16: NSMaxRange(sel)))
        formatNow(buffer, thenSave: false, startByte: start, endByte: end)
    }

    private func formatNow(_ buffer: BufferDocument, thenSave: Bool, startByte: UInt32?, endByte: UInt32?) {
        guard !buffer.isReadOnly else {
            return
        }
        EditorPanes.shared.host(bound: buffer)?.capture()
        let text = buffer.text
        let edition = projectRoot(for: buffer.fileURL).flatMap(cargoEdition)
        let path = buffer.fileURL?.path ?? "untitled.\(buffer.language.fileExtension)"
        let language = buffer.language
        let id = buffer.id
        RideEngineClient.shared.withEngine { engine in
            Result {
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
        } then: { [weak self] result in
            self?.formatFinished(result, bufferID: id, thenSave: thenSave)
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
        guard let buffer = buffer(bufferID) else {
            return
        }
        switch result {
        case .success(let formatted):
            formatError = nil
            guard formatted != buffer.text else {
                showNotice("\(buffer.displayName) is already formatted", seconds: 2)
                return
            }
            deliver(formatted, to: buffer, disk: thenSave ? .save : .dirty)
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
