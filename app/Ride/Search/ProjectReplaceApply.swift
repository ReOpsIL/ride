import AppKit

extension AppState {
    func applyProjectReplace() {
        let model = projectFind
        let query = model.query.trimmingCharacters(in: .whitespaces)
        let options = model.options
        let hits = currentHits(model.chosenHits, query: query, options: options)
        let edits = ProjectReplace.edits(
            hits: hits,
            query: query,
            replacement: model.replacement,
            options: options
        )
        var paths: [String] = []
        for edit in edits where write(edit) {
            paths.append(edit.file.path)
        }
        model.showPreview = false
        showProjectFind = false
        if !paths.isEmpty {
            filesChanged(paths)
            let matches = hits.reduce(0) { $0 + $1.ranges.count }
            notice = "Replaced \(Plural.count(matches, "match", plural: "matches")) in \(Plural.count(edits.count, "file"))"
        }
    }

    private func currentHits(_ hits: [FileHit], query: String, options: FindOptions) -> [FileHit] {
        hits.map { hit in
            guard let buffer = buffers.first(where: { $0.fileURL == hit.file }) else {
                return hit
            }
            if buffer.id == activeID, let view = EditorPanes.shared.focusedView {
                buffer.capture(view)
            }
            let text = buffer.text
            return FileHit(
                file: hit.file,
                text: text,
                ranges: FindMatcher.matches(in: text, query: query, options: options)
            )
        }
    }

    private func write(_ edit: FileEdit) -> Bool {
        if let buffer = buffers.first(where: { $0.fileURL == edit.file }) {
            return writeBuffer(buffer, text: edit.text)
        }
        return writeDisk(edit)
    }

    private func writeBuffer(_ buffer: BufferDocument, text: String) -> Bool {
        guard !buffer.isReadOnly, buffer.fileURL != nil else {
            return false
        }
        buffer.text = text
        try? buffer.save(from: nil)
        if buffer.id == activeID {
            applyText = text
            applyThenSave = false
        }
        didSave(buffer, allowFormat: false)
        return true
    }

    private func writeDisk(_ edit: FileEdit) -> Bool {
        do {
            try edit.text.write(to: edit.file, atomically: true, encoding: .utf8)
            RideEngineClient.shared.engine?.workspaceFileChanged(path: edit.file.path)
            return true
        } catch {
            return false
        }
    }
}
