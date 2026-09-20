import Foundation

struct LineEdit: Equatable {
    let firstLine: Int
    let lastLine: Int
    let removedLines: Int
    let insertedLines: Int
    let startsAtLineStart: Bool
    let endsAtLineStart: Bool

    var delta: Int {
        insertedLines - removedLines
    }

    func newLine(for line: Int) -> Int? {
        if line < firstLine {
            return line
        }
        if line == firstLine {
            return firstLineTarget()
        }
        if line > lastLine || (line == lastLine && endsAtLineStart) {
            return line + delta
        }
        return nil
    }

    private func firstLineTarget() -> Int? {
        if !startsAtLineStart {
            return firstLine
        }
        if removedLines > 0 {
            return nil
        }
        return firstLine + insertedLines
    }
}

enum BreakpointShift {
    private static let newline: unichar = 10

    static func lineEdit(before: String, range: NSRange, inserted: String) -> LineEdit {
        let text = before as NSString
        let start = min(max(range.location, 0), text.length)
        let end = min(max(NSMaxRange(range), start), text.length)
        let first = newlines(in: text, upTo: start) + 1
        let removed = newlines(in: text, from: start, upTo: end)
        let added = inserted.utf16.reduce(into: 0) { total, unit in
            total += unit == newline ? 1 : 0
        }
        return LineEdit(
            firstLine: first,
            lastLine: first + removed,
            removedLines: removed,
            insertedLines: added,
            startsAtLineStart: isLineStart(text, start),
            endsAtLineStart: end > start && isLineStart(text, end)
        )
    }

    private static func isLineStart(_ text: NSString, _ offset: Int) -> Bool {
        offset == 0 || text.character(at: offset - 1) == newline
    }

    private static func newlines(in text: NSString, upTo end: Int) -> Int {
        newlines(in: text, from: 0, upTo: end)
    }

    private static func newlines(in text: NSString, from start: Int, upTo end: Int) -> Int {
        var count = 0
        var index = start
        while index < end {
            count += text.character(at: index) == newline ? 1 : 0
            index += 1
        }
        return count
    }
}

extension Breakpoints {
    mutating func shift(path: String, edit: LineEdit) -> Bool {
        let current = marks(path: path)
        let moved = current.compactMap { mark -> BreakpointMark? in
            guard let line = edit.newLine(for: Int(mark.line)) else {
                return nil
            }
            var shifted = mark
            shifted.line = UInt32(line)
            return shifted
        }
        guard moved != current else {
            return false
        }
        replace(path: path, marks: moved)
        return true
    }
}
