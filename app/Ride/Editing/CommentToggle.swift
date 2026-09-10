import Foundation

enum CommentToggle {
    static func toggleLine(_ text: String, selection: NSRange, tokens: CommentTokens) -> EditResult {
        guard let token = tokens.line else {
            return toggleBlock(text, selection: selection, tokens: tokens)
        }
        let source = text as NSString
        let lines = LineSpan.lines(source, selection)
        let nonBlank = lines.filter { !LineSpan.isBlank(source, line: $0) }
        let targets = nonBlank.isEmpty ? lines : nonBlank
        let changes: [TextChange]
        if targets.allSatisfy({ commentRange(source, line: $0, token: token) != nil }) {
            changes = targets.compactMap { commentRange(source, line: $0, token: token) }.map(TextChange.init(delete:))
        } else {
            let column = targets.map { LineSpan.indentationLength(source, line: $0) }.min() ?? 0
            changes = targets.map { TextChange(insert: token + " ", at: $0.location + column) }
        }
        return EditResult.mapping(selection, through: changes)
    }

    private static func commentRange(_ text: NSString, line: NSRange, token: String) -> NSRange? {
        let start = line.location + LineSpan.indentationLength(text, line: line)
        let width = token.utf16.count
        guard start + width <= line.upperBound,
              text.substring(with: NSRange(location: start, length: width)) == token
        else {
            return nil
        }
        let trailingSpace = start + width < line.upperBound && text.character(at: start + width) == 0x20
        return NSRange(location: start, length: width + (trailingSpace ? 1 : 0))
    }

    static func toggleBlock(_ text: String, selection: NSRange, tokens: CommentTokens) -> EditResult {
        guard let open = tokens.blockOpen, let close = tokens.blockClose else {
            return .keep(selection)
        }
        let source = text as NSString
        let range = selection.length > 0 ? trimmed(source, selection) : LineSpan.contentRange(source, at: selection.location)
        let selected = source.substring(with: range)
        if selected.hasPrefix(open), selected.hasSuffix(close), selected.utf16.count >= (open + close).utf16.count {
            return unwrap(selected, range: range, open: open, close: close)
        }
        let changes = [
            TextChange(insert: open + " ", at: range.location),
            TextChange(insert: " " + close, at: range.upperBound),
        ]
        let width = range.length + (open + close).utf16.count + 2
        return EditResult(changes: changes, selection: NSRange(location: range.location, length: width))
    }

    private static func trimmed(_ source: NSString, _ selection: NSRange) -> NSRange {
        let whitespace = CharacterSet.whitespacesAndNewlines
        var start = selection.location
        var end = selection.upperBound
        while start < end, let scalar = Unicode.Scalar(source.character(at: start)), whitespace.contains(scalar) {
            start += 1
        }
        while end > start, let scalar = Unicode.Scalar(source.character(at: end - 1)), whitespace.contains(scalar) {
            end -= 1
        }
        return start < end ? NSRange(location: start, length: end - start) : selection
    }

    private static func unwrap(_ selected: String, range: NSRange, open: String, close: String) -> EditResult {
        let inner = selected.dropFirst(open.count).dropLast(close.count)
        let leading = open.utf16.count + (inner.hasPrefix(" ") ? 1 : 0)
        let trailing = close.utf16.count + (inner.hasSuffix(" ") && inner.count > 1 ? 1 : 0)
        let changes = [
            TextChange(delete: NSRange(location: range.location, length: leading)),
            TextChange(delete: NSRange(location: range.upperBound - trailing, length: trailing)),
        ]
        let width = max(0, range.length - leading - trailing)
        return EditResult(changes: changes, selection: NSRange(location: range.location, length: width))
    }
}
