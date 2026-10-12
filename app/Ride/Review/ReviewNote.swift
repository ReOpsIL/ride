import Foundation

extension ReviewModel {
    func cachedNote(for row: ReviewRow) -> String? {
        noteCache[noteKey(row)]
    }

    func generateNote(_ row: ReviewRow, root: String?, config: AIConfig) {
        let key = noteKey(row)
        if let cached = noteCache[key] {
            noteDraft = cached
            return
        }
        guard let root, !root.isEmpty else {
            return
        }
        let source = itemSource(root: root, row: row)
        noting = true
        AIClient.ask({
            (
                AIPromptInput(language: "", path: row.path, prefix: source, suffix: "", extras: []),
                "Write a short review note for this item. Use only the code you were given. No score.",
                row.signature
            )
        }, config: config) { [weak self] result in
            guard let self else {
                return
            }
            self.noting = false
            switch result {
            case .success(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                self.noteCache[key] = trimmed
                self.noteDraft = trimmed
            case .failure(let error):
                self.error = error.message
            }
        }
    }

    func shareNote(_ row: ReviewRow, root: String?) {
        let text = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }
        mark(row, root: root, kind: "note", note: text)
    }

    private func noteKey(_ row: ReviewRow) -> String {
        "\(row.path)\n\(row.item)\n\(row.shape)"
    }

    private func itemSource(root: String, row: ReviewRow) -> String {
        let url = URL(fileURLWithPath: root).appendingPathComponent(row.path)
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8),
              row.startByte <= row.endByte,
              Int(row.endByte) <= text.utf8.count
        else {
            return row.signature
        }
        let bytes = Array(text.utf8)
        let slice = bytes[Int(row.startByte)..<Int(row.endByte)]
        return String(decoding: slice, as: UTF8.self)
    }
}
