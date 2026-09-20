import Foundation

struct UndoEdit: Equatable {
    let range: NSRange
    let text: String

    static func inverse(before: String, after: String) -> UndoEdit? {
        guard let edit = TextDiff.minimalEdit(from: before, to: after) else {
            return nil
        }
        return UndoEdit(
            range: NSRange(location: edit.range.location, length: (edit.text as NSString).length),
            text: (before as NSString).substring(with: edit.range)
        )
    }

    var isTyping: Bool {
        text.isEmpty && range.length == 1
    }

    var caret: Int {
        range.location + (text as NSString).length
    }

    func extended(by next: UndoEdit) -> UndoEdit? {
        guard text.isEmpty, next.isTyping, next.range.location == NSMaxRange(range) else {
            return nil
        }
        return UndoEdit(
            range: NSRange(location: range.location, length: range.length + next.range.length),
            text: text
        )
    }
}
