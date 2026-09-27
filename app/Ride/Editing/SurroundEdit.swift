import Foundation

enum SurroundEdit {
    static func result(_ template: SurroundTemplate, text: String, selection: NSRange, unit: String) -> EditResult {
        switch template.shape {
        case .inline:
            return inline(template, text: text as NSString, selection: selection)
        case .block(let indentBody):
            return block(template, text: text as NSString, selection: selection, unit: indentBody ? unit : "")
        }
    }

    private static func inline(_ template: SurroundTemplate, text: NSString, selection: NSRange) -> EditResult {
        let selected = text.substring(with: selection)
        let inner = NSRange(location: selection.location + template.open.utf16.count, length: selected.utf16.count)
        return EditResult(changes: [TextChange(range: selection, text: template.open + selected + template.close)], selection: inner)
    }

    private static func block(_ template: SurroundTemplate, text: NSString, selection: NSRange, unit: String) -> EditResult {
        let lines = contentLines(text, selection)
        let base = LineSpan.indentation(text, line: lines)
        let body = indented(text.substring(with: lines), base: base, unit: unit)
        let head = base + template.open + "\n"
        let replacement = head + body + "\n" + base + template.close
        let bodyStart = lines.location + head.utf16.count
        return EditResult(
            changes: [TextChange(range: lines, text: replacement)],
            selection: focus(template, head: head, lineStart: lines.location)
                ?? bodyFocus(body, start: bodyStart, blank: LineSpan.isBlank(text, line: lines))
        )
    }

    private static func contentLines(_ text: NSString, _ selection: NSRange) -> NSRange {
        let full = LineSpan.lineRange(text, selection)
        let trailing = full.length > 0 && text.character(at: NSMaxRange(full) - 1) == 0x0A ? 1 : 0
        return NSRange(location: full.location, length: full.length - trailing)
    }

    private static func indented(_ body: String, base: String, unit: String) -> String {
        let lines = body.components(separatedBy: "\n")
        if lines.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            return base + unit
        }
        return lines.map { $0.isEmpty ? $0 : unit + $0 }.joined(separator: "\n")
    }

    private static func focus(_ template: SurroundTemplate, head: String, lineStart: Int) -> NSRange? {
        guard let placeholder = template.placeholder else {
            return nil
        }
        let found = (head as NSString).range(of: placeholder)
        guard found.location != NSNotFound else {
            return nil
        }
        return NSRange(location: lineStart + found.location, length: found.length)
    }

    private static func bodyFocus(_ body: String, start: Int, blank: Bool) -> NSRange {
        let length = body.utf16.count
        return blank ? NSRange(location: start + length, length: 0) : NSRange(location: start, length: length)
    }
}
