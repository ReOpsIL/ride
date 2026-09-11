import AppKit

extension AppState {
    func applyProjectReplace() {
        let model = projectFind
        let query = model.query.trimmingCharacters(in: .whitespaces)
        let options = model.options
        let hits = ProjectReplace.refresh(model.chosenHits, query: query, options: options, text: liveText)
        let planned = ProjectReplace.edits(
            hits: hits,
            query: query,
            replacement: model.replacement,
            options: options
        )
        let saved = saveEdits(planned.edits)
        model.showPreview = false
        showProjectFind = false
        if !saved.written.isEmpty {
            filesChanged(saved.written.map(\.path))
        }
        let written = Set(saved.written)
        let matches = hits.reduce(0) { count, hit in
            written.contains(hit.file) ? count + hit.ranges.count : count
        }
        if let text = ProjectReplace.summary(
            matches: matches,
            files: saved.written.count,
            skipped: planned.skipped,
            failed: saved.failed
        ) {
            notice = text
        }
    }

    private func liveText(_ file: URL) -> String? {
        if let buffer = buffers.first(where: { $0.fileURL == file }) {
            if buffer.id == activeID, let view = EditorPanes.shared.focusedView {
                buffer.capture(view)
            }
            return buffer.text
        }
        return ProjectFind.readText(file)
    }

    private func saveEdits(_ edits: [FileEdit]) -> (written: [URL], failed: [URL]) {
        var written: [URL] = []
        var failed: [URL] = []
        for edit in edits {
            if write(edit) {
                written.append(edit.file)
            } else {
                failed.append(edit.file)
            }
        }
        return (written, failed)
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
        let previous = buffer.text
        let dirty = buffer.isDirty
        buffer.text = text
        do {
            try buffer.save(from: nil)
        } catch {
            buffer.text = previous
            buffer.isDirty = dirty
            return false
        }
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
