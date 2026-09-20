import Foundation

struct LineEdit: Equatable {
    let firstLine: Int
    let lastLine: Int
    let newLastLine: Int
}

enum BreakpointShift {
    static func lineEdit(before: String, range: NSRange, inserted: String) -> LineEdit {
        let text = before as NSString
        let first = line(in: text, at: range.location)
        let last = line(in: text, at: NSMaxRange(range))
        let added = inserted.utf16.reduce(into: 0) { total, unit in
            total += unit == newline ? 1 : 0
        }
        return LineEdit(firstLine: first, lastLine: last, newLastLine: first + added)
    }

    private static let newline: unichar = 10

    private static func line(in text: NSString, at offset: Int) -> Int {
        let end = min(max(offset, 0), text.length)
        var line = 1
        var index = 0
        while index < end {
            line += text.character(at: index) == newline ? 1 : 0
            index += 1
        }
        return line
    }
}

extension Breakpoints {
    mutating func shift(path: String, edit: LineEdit) -> Bool {
        let current = marks(path: path)
        let delta = edit.newLastLine - edit.lastLine
        let moved = current.compactMap { mark -> BreakpointMark? in
            let line = Int(mark.line)
            if line <= edit.firstLine {
                return mark
            }
            guard line > edit.lastLine else {
                return nil
            }
            var shifted = mark
            shifted.line = UInt32(line + delta)
            return shifted
        }
        guard moved != current else {
            return false
        }
        replace(path: path, marks: moved)
        return true
    }
}
