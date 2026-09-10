import Foundation

enum LineOps {
    static func indent(_ text: String, selection: NSRange, unit: String) -> EditResult {
        let source = text as NSString
        let lines = LineSpan.lines(source, selection)
        let changes = lines
            .filter { lines.count == 1 || !LineSpan.isBlank(source, line: $0) }
            .map { TextChange(insert: unit, at: $0.location) }
        return EditResult.mapping(selection, through: changes)
    }

    static func unindent(_ text: String, selection: NSRange, width: Int) -> EditResult {
        let source = text as NSString
        let changes = LineSpan.lines(source, selection).compactMap { line -> TextChange? in
            let removed = removableIndent(source, line: line, width: width)
            guard removed > 0 else {
                return nil
            }
            return TextChange(delete: NSRange(location: line.location, length: removed))
        }
        return EditResult.mapping(selection, through: changes)
    }

    private static func removableIndent(_ text: NSString, line: NSRange, width: Int) -> Int {
        guard line.length > 0 else {
            return 0
        }
        if text.character(at: line.location) == 0x09 {
            return 1
        }
        var count = 0
        while count < width, count < line.length, text.character(at: line.location + count) == 0x20 {
            count += 1
        }
        return count
    }

    static func duplicate(_ text: String, selection: NSRange) -> EditResult {
        let source = text as NSString
        let selected = source.substring(with: selection)
        if selection.length > 0, !selected.contains("\n") {
            let change = TextChange(insert: selected, at: selection.upperBound)
            return EditResult(changes: [change], selection: NSRange(location: selection.upperBound, length: selection.length))
        }
        let span = LineSpan.lineRange(source, selection)
        var block = source.substring(with: span)
        var insertAt = span.upperBound
        var offset = span.length
        if !block.hasSuffix("\n") {
            block = "\n" + block
            insertAt = source.length
            offset = span.length + 1
        }
        let change = TextChange(insert: block, at: insertAt)
        return EditResult(changes: [change], selection: NSRange(location: selection.location + offset, length: selection.length))
    }

    static func deleteLines(_ text: String, selection: NSRange) -> EditResult {
        let source = text as NSString
        var span = LineSpan.lineRange(source, selection)
        let column = selection.location - span.location
        if span.upperBound == source.length, span.location > 0 {
            span = NSRange(location: span.location - 1, length: span.length + 1)
        }
        let change = TextChange(delete: span)
        let result = EditResult.applying([change], to: text) as NSString
        let lineStart = LineSpan.lineStart(result, at: min(span.location, result.length))
        let caret = min(lineStart + column, LineSpan.lineEnd(result, at: lineStart))
        return EditResult(changes: [change], selection: NSRange(location: caret, length: 0))
    }

    static func joinLines(_ text: String, selection: NSRange) -> EditResult {
        let source = text as NSString
        var lines = LineSpan.lines(source, selection)
        if lines.count == 1, let next = LineSpan.nextLine(source, after: lines[0]) {
            lines.append(next)
        }
        guard lines.count > 1 else {
            return .keep(selection)
        }
        let changes = zip(lines, lines.dropFirst()).map { seam(source, upper: $0, lower: $1) }
        let mapped = EditResult.mapping(selection, through: changes)
        guard selection.length == 0, let first = changes.first else {
            return mapped
        }
        return EditResult(changes: changes, selection: NSRange(location: first.range.location, length: 0))
    }

    private static func seam(_ text: NSString, upper: NSRange, lower: NSRange) -> TextChange {
        var start = upper.upperBound
        while start > upper.location, LineSpan.isHorizontalSpace(text.character(at: start - 1)) {
            start -= 1
        }
        let end = lower.location + LineSpan.indentationLength(text, line: lower)
        let joinsContent = start > upper.location && end < lower.upperBound
        return TextChange(range: NSRange(location: start, length: end - start), text: joinsContent ? " " : "")
    }

    static func sortLines(_ text: String, selection: NSRange) -> EditResult {
        let source = text as NSString
        let scope = selection.length == 0 ? NSRange(location: 0, length: source.length) : selection
        let lines = LineSpan.lines(source, scope)
        let sorted = lines.map { source.substring(with: $0) }.sorted()
        let span = NSRange(location: lines[0].location, length: lines[lines.count - 1].upperBound - lines[0].location)
        let change = TextChange(range: span, text: sorted.joined(separator: "\n"))
        return EditResult(changes: [change], selection: selection)
    }
}
