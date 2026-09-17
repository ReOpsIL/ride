import AppKit

enum RenameApply {
    private enum Outcome {
        case applied(Int)
        case changed
        case failed
        case noop
    }

    static func applyLocal(_ edits: [TextEdit], to view: RideTextView) {
        guard !edits.isEmpty else {
            return
        }
        let map = Utf16Map(view.string)
        let changes = edits
            .map { TextChange(range: map.nsRange(startByte: $0.startByte, endByte: $0.endByte), text: $0.text) }
            .sorted { $0.range.location < $1.range.location }
        let result = EditResult.mapping(view.selectedRange(), through: changes)
        EditorCommand.apply(result, to: view)
    }

    static func applyWorkspace(state: AppState, plan: RenamePlan, chosenFiles: Set<String>, chosenReview: Set<Int>) {
        var applied = 0
        var files = 0
        var written: [String] = []
        var changed: [String] = []
        var failed: [String] = []
        for (path, edits) in gather(plan: plan, chosenFiles: chosenFiles, chosenReview: chosenReview) {
            let url = state.resolveRenameURL(path)
            switch applyFile(state: state, url: url, name: plan.name, edits: edits) {
            case let .applied(count):
                applied += count
                files += 1
                written.append(url.path)
            case .changed:
                changed.append(url.lastPathComponent)
            case .failed:
                failed.append(url.lastPathComponent)
            case .noop:
                break
            }
        }
        if !written.isEmpty {
            state.filesChanged(written)
        }
        if let text = summary(applied: applied, files: files, changed: changed, failed: failed) {
            state.notice = text
        }
    }

    private static func gather(plan: RenamePlan, chosenFiles: Set<String>, chosenReview: Set<Int>) -> [(String, [TextEdit])] {
        var map: [String: [TextEdit]] = [:]
        for file in plan.files where chosenFiles.contains(file.path) {
            map[file.path, default: []].append(contentsOf: file.edits)
        }
        for (index, file) in plan.review.enumerated() where chosenReview.contains(index) {
            map[file.path, default: []].append(contentsOf: file.edits)
        }
        return map
            .map { ($0.key, $0.value.sorted { $0.startByte < $1.startByte }) }
            .sorted { $0.0 < $1.0 }
    }

    private static func applyFile(state: AppState, url: URL, name: String, edits: [TextEdit]) -> Outcome {
        let buffer = state.buffer(for: url)
        let view = buffer.flatMap { state.editorView(for: $0) }
        guard let text = view?.string ?? buffer?.text ?? state.liveText(url) else {
            return .failed
        }
        guard let changes = validate(text: text, name: name, edits: edits) else {
            return .changed
        }
        guard !changes.isEmpty else {
            return .noop
        }
        if let view, let buffer {
            let result = EditResult.mapping(view.selectedRange(), through: changes)
            EditorCommand.apply(result, to: view)
            return persist(state, buffer) ? .applied(changes.count) : .failed
        }
        if let buffer {
            return applyBackground(state, buffer, EditResult.applying(changes, to: text), count: changes.count)
        }
        return writeDisk(url, EditResult.applying(changes, to: text), count: changes.count)
    }

    private static func applyBackground(
        _ state: AppState,
        _ buffer: BufferDocument,
        _ text: String,
        count: Int
    ) -> Outcome {
        var ok = true
        BufferTextUndo.apply(text, to: buffer, undo: buffer.undoManager) { [weak state] doc in
            guard let state else {
                return
            }
            if persist(state, doc) {
                resync(doc)
                if let host = EditorPanes.shared.host(bound: doc), host.textView.string != doc.text {
                    host.bind(doc)
                }
            } else {
                ok = false
            }
        }
        return ok ? .applied(count) : .failed
    }

    private static func validate(text: String, name: String, edits: [TextEdit]) -> [TextChange]? {
        let map = Utf16Map(text)
        let ns = text as NSString
        var changes: [TextChange] = []
        for edit in edits {
            let range = map.nsRange(startByte: edit.startByte, endByte: edit.endByte)
            guard NSMaxRange(range) <= ns.length, ns.substring(with: range) == name else {
                return nil
            }
            changes.append(TextChange(range: range, text: edit.text))
        }
        return changes.sorted { $0.range.location < $1.range.location }
    }

    private static func persist(_ state: AppState, _ buffer: BufferDocument) -> Bool {
        guard !buffer.isReadOnly else {
            return false
        }
        do {
            try buffer.save(from: nil)
        } catch {
            return false
        }
        state.didSave(buffer, allowFormat: false)
        return true
    }

    private static func resync(_ buffer: BufferDocument) {
        guard let id = buffer.sessionId else {
            return
        }
        let text = buffer.text
        DispatchQueue.global(qos: .userInitiated).async {
            _ = try? RideEngineClient.shared.engine?.setText(sessionId: id, text: text, visible: nil)
        }
    }

    private static func writeDisk(_ url: URL, _ text: String, count: Int) -> Outcome {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return .failed
        }
        RideEngineClient.shared.engine?.workspaceFileChanged(path: url.path)
        return .applied(count)
    }

    private static func summary(applied: Int, files: Int, changed: [String], failed: [String]) -> String? {
        var parts: [String] = []
        if files > 0 {
            parts.append("Renamed \(Plural.count(applied, "occurrence")) in \(Plural.count(files, "file"))")
        }
        if !changed.isEmpty {
            parts.append("\(Plural.count(changed.count, "file")) skipped — changed since indexing")
        }
        if !failed.isEmpty {
            parts.append("Failed \(failed.joined(separator: ", "))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }
}

extension BufferDocument: TextUndoTarget {
    var undoText: String {
        get { text }
        set { text = newValue }
    }
}
