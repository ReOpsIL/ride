import Foundation

extension SmartIndent {
    static func autoIndent(_ text: String, selection: NSRange, unit: String) -> EditResult {
        let source = text as NSString
        var reindented: [Int: String] = [:]
        var changes: [TextChange] = []
        for line in LineSpan.lines(source, selection) where !LineSpan.isBlank(source, line: line) {
            let wanted = expectedIndent(source, line: line, unit: unit, reindented: reindented)
            reindented[line.location] = wanted
            let current = NSRange(location: line.location, length: LineSpan.indentationLength(source, line: line))
            if source.substring(with: current) != wanted {
                changes.append(TextChange(range: current, text: wanted))
            }
        }
        return EditResult.mapping(selection, through: changes)
    }

    private static func expectedIndent(_ text: NSString, line: NSRange, unit: String, reindented: [Int: String]) -> String {
        guard let previous = LineSpan.previousNonBlank(text, before: line) else {
            return ""
        }
        var indent = reindented[previous.location] ?? LineSpan.indentation(text, line: previous)
        let previousContent = text.substring(with: previous).trimmingCharacters(in: .whitespaces)
        if opensBlock(previousContent, unit: unit) {
            indent += unit
        }
        let content = text.substring(with: line).trimmingCharacters(in: .whitespaces)
        if let first = content.first, closers.contains(first) {
            indent = indent.hasSuffix(unit) ? String(indent.dropLast(unit.count)) : String(indent.dropLast(min(unit.count, indent.count)))
        }
        return indent
    }
}
