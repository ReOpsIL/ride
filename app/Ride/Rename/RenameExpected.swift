import Foundation

enum RenameExpected {
    static func key(_ edit: TextEdit) -> String {
        "\(edit.startByte):\(edit.endByte)"
    }

    static func capture(plan: RenamePlan, state: AppState) -> [String: [String: String]] {
        var out: [String: [String: String]] = [:]
        for file in plan.files + plan.review {
            guard let text = state.liveText(state.resolveRenameURL(file.path)) else {
                continue
            }
            let map = Utf16Map(text)
            let ns = text as NSString
            var slices = out[file.path] ?? [:]
            for edit in file.edits {
                let range = map.nsRange(startByte: edit.startByte, endByte: edit.endByte)
                if NSMaxRange(range) <= ns.length {
                    slices[key(edit)] = ns.substring(with: range)
                }
            }
            out[file.path] = slices
        }
        return out
    }

    static func changes(
        text: String,
        name: String,
        edits: [TextEdit],
        expected: [String: String]
    ) -> [TextChange]? {
        let map = Utf16Map(text)
        let ns = text as NSString
        var changes: [TextChange] = []
        for edit in edits {
            let range = map.nsRange(startByte: edit.startByte, endByte: edit.endByte)
            guard NSMaxRange(range) <= ns.length else {
                return nil
            }
            let current = ns.substring(with: range)
            let wanted = expected[RenameExpected.key(edit)] ?? (edit.text.isEmpty ? nil : name)
            guard let wanted, current == wanted else {
                return nil
            }
            changes.append(TextChange(range: range, text: edit.text))
        }
        return changes.sorted { $0.range.location < $1.range.location }
    }
}
