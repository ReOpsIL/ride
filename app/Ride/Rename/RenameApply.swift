import AppKit

enum RenameApply {
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

    static func applyWorkspace(state: AppState, plan: RenamePlan, chosen: Set<String>) {
        let edits = plan.files
            .filter { chosen.contains($0.path) }
            .compactMap { fileEdit(state: state, file: $0) }
        let saved = state.saveEdits(edits)
        if !saved.written.isEmpty {
            state.filesChanged(saved.written.map(\.path))
        }
        if let text = summary(plan: plan, saved: saved) {
            state.notice = text
        }
    }

    private static func fileEdit(state: AppState, file: RenameFile) -> FileEdit? {
        let url = state.resolveRenameURL(file.path)
        guard let text = state.liveText(url) else {
            return nil
        }
        let map = Utf16Map(text)
        let mutable = NSMutableString(string: text)
        for edit in file.edits.sorted(by: { $0.startByte > $1.startByte }) {
            let range = map.nsRange(startByte: edit.startByte, endByte: edit.endByte)
            guard NSMaxRange(range) <= mutable.length else {
                return nil
            }
            mutable.replaceCharacters(in: range, with: edit.text)
        }
        let next = mutable as String
        guard next != text else {
            return nil
        }
        return FileEdit(file: url, text: next)
    }

    private static func summary(plan: RenamePlan, saved: (written: [URL], failed: [URL])) -> String? {
        var parts: [String] = []
        let writtenPaths = saved.written.map(\.path)
        let edits = plan.files
            .filter { file in writtenPaths.contains(where: { $0.hasSuffix(file.path) }) }
            .reduce(0) { $0 + $1.edits.count }
        if !saved.written.isEmpty {
            parts.append("Renamed \(Plural.count(edits, "occurrence")) in \(Plural.count(saved.written.count, "file"))")
        }
        if !saved.failed.isEmpty {
            parts.append("Failed \(saved.failed.map(\.lastPathComponent).joined(separator: ", "))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }
}
