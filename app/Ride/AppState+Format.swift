import AppKit

extension AppState {
    func formatsOnSave(_ buffer: BufferDocument) -> Bool {
        guard let engine = RideEngineClient.shared.engine else {
            return false
        }
        return !engine.formatterName(path: buffer.fileURL?.path, text: buffer.text).isEmpty
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

    func formatNow(_ buffer: BufferDocument, thenSave: Bool, startByte: UInt32?, endByte: UInt32?) {
        guard !buffer.isReadOnly else {
            return
        }
        EditorPanes.shared.host(bound: buffer)?.capture()
        let text = buffer.text
        let edition = projectRoot(for: buffer.fileURL).flatMap(cargoEdition)
        let path = buffer.fileURL?.path ?? "untitled.\(buffer.language.fileExtension)"
        let language = buffer.language
        let id = buffer.id
        let mark = buffer.textGeneration
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
            self?.formatFinished(result, bufferID: id, mark: mark, thenSave: thenSave)
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

    private func formatFinished(_ result: Result<String, Error>, bufferID: UUID, mark: Int, thenSave: Bool) {
        guard let buffer = buffer(bufferID) else {
            return
        }
        guard buffer.textGeneration == mark else {
            if !thenSave {
                showNotice("\(buffer.displayName) changed while formatting", seconds: 2)
            }
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
