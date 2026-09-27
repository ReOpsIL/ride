import Foundation

struct TextChange: Equatable {
    let range: NSRange
    let text: String

    init(range: NSRange, text: String) {
        self.range = range
        self.text = text
    }

    init(insert text: String, at location: Int) {
        self.init(range: NSRange(location: location, length: 0), text: text)
    }

    init(delete range: NSRange) {
        self.init(range: range, text: "")
    }

    var delta: Int {
        text.utf16.count - range.length
    }

    static func ordered(_ changes: [TextChange]) -> [TextChange]? {
        let sorted = changes.enumerated()
            .sorted { ($0.element.range.location, $0.element.range.length, $0.offset) < ($1.element.range.location, $1.element.range.length, $1.offset) }
            .map(\.element)
        for (earlier, later) in zip(sorted, sorted.dropFirst()) where NSMaxRange(earlier.range) > later.range.location {
            return nil
        }
        return sorted
    }
}

struct EditResult: Equatable {
    let changes: [TextChange]
    let selection: NSRange

    init(changes: [TextChange], selection: NSRange) {
        self.changes = TextChange.ordered(changes) ?? []
        self.selection = selection
    }

    static func keep(_ selection: NSRange) -> EditResult {
        EditResult(changes: [], selection: selection)
    }

    static func applying(_ changes: [TextChange], to text: String) -> String {
        guard let ordered = TextChange.ordered(changes) else {
            return text
        }
        let result = NSMutableString(string: text)
        for change in ordered.reversed() {
            result.replaceCharacters(in: change.range, with: change.text)
        }
        return result as String
    }

    static func shift(_ offset: Int, through changes: [TextChange], inclusive: Bool) -> Int {
        var shifted = offset
        for change in changes {
            let start = change.range.location
            let end = change.range.upperBound
            if start > offset || (start == offset && !(inclusive && change.range.length == 0)) {
                break
            }
            if end <= offset {
                shifted += change.delta
            } else {
                shifted = start + change.text.utf16.count
                break
            }
        }
        return shifted
    }

    static func mapping(_ selection: NSRange, through unordered: [TextChange]) -> EditResult {
        let changes = TextChange.ordered(unordered) ?? []
        if selection.length == 0 {
            let caret = shift(selection.location, through: changes, inclusive: true)
            return EditResult(changes: changes, selection: NSRange(location: caret, length: 0))
        }
        let start = shift(selection.location, through: changes, inclusive: false)
        let end = shift(selection.upperBound, through: changes, inclusive: true)
        return EditResult(changes: changes, selection: NSRange(location: start, length: max(0, end - start)))
    }
}
