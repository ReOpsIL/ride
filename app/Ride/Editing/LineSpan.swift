import Foundation

enum LineSpan {
    static let newline: unichar = 0x0A

    static func lineStart(_ text: NSString, at location: Int) -> Int {
        var index = min(location, text.length)
        while index > 0, text.character(at: index - 1) != newline {
            index -= 1
        }
        return index
    }

    static func lineEnd(_ text: NSString, at location: Int) -> Int {
        var index = min(location, text.length)
        while index < text.length, text.character(at: index) != newline {
            index += 1
        }
        return index
    }

    static func contentRange(_ text: NSString, at location: Int) -> NSRange {
        let start = lineStart(text, at: location)
        return NSRange(location: start, length: lineEnd(text, at: location) - start)
    }

    static func lastTouched(_ text: NSString, _ selection: NSRange) -> Int {
        let end = selection.upperBound
        if selection.length > 0, end > 0, text.character(at: end - 1) == newline {
            return end - 1
        }
        return end
    }

    static func lineRange(_ text: NSString, _ selection: NSRange) -> NSRange {
        let start = lineStart(text, at: selection.location)
        let end = lineEnd(text, at: lastTouched(text, selection))
        return NSRange(location: start, length: min(end + 1, text.length) - start)
    }

    static func lines(_ text: NSString, _ selection: NSRange) -> [NSRange] {
        var ranges: [NSRange] = []
        let last = lastTouched(text, selection)
        var cursor = lineStart(text, at: selection.location)
        repeat {
            let line = contentRange(text, at: cursor)
            ranges.append(line)
            cursor = line.upperBound + 1
        } while cursor <= last && cursor <= text.length
        return ranges
    }

    static func indentationLength(_ text: NSString, line: NSRange) -> Int {
        var index = line.location
        while index < line.upperBound, isHorizontalSpace(text.character(at: index)) {
            index += 1
        }
        return index - line.location
    }

    static func indentation(_ text: NSString, line: NSRange) -> String {
        text.substring(with: NSRange(location: line.location, length: indentationLength(text, line: line)))
    }

    static func isBlank(_ text: NSString, line: NSRange) -> Bool {
        indentationLength(text, line: line) == line.length
    }

    static func previousNonBlank(_ text: NSString, before line: NSRange) -> NSRange? {
        var cursor = line.location
        while cursor > 0 {
            let previous = contentRange(text, at: cursor - 1)
            if !isBlank(text, line: previous) {
                return previous
            }
            cursor = previous.location
        }
        return nil
    }

    static func nextLine(_ text: NSString, after line: NSRange) -> NSRange? {
        guard line.upperBound < text.length else {
            return nil
        }
        return contentRange(text, at: line.upperBound + 1)
    }

    static func isHorizontalSpace(_ unit: unichar) -> Bool {
        unit == 0x20 || unit == 0x09
    }
}
