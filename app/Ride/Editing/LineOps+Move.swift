import Foundation

extension LineOps {
    static func moveLines(_ text: String, selection: NSRange, up: Bool) -> EditResult {
        let source = text as NSString
        let span = LineSpan.lineRange(source, selection)
        return up ? moveUp(source, span: span, selection: selection) : moveDown(source, span: span, selection: selection)
    }

    private static func moveUp(_ text: NSString, span: NSRange, selection: NSRange) -> EditResult {
        guard span.location > 0 else {
            return .keep(selection)
        }
        let above = LineSpan.contentRange(text, at: span.location - 1)
        let aboveSpan = NSRange(location: above.location, length: span.location - above.location)
        let swapped = swap(first: text.substring(with: aboveSpan), second: text.substring(with: span))
        let change = TextChange(range: NSUnionRange(aboveSpan, span), text: swapped)
        return EditResult(changes: [change], selection: shifted(selection, by: -aboveSpan.length, in: text, change: change))
    }

    private static func moveDown(_ text: NSString, span: NSRange, selection: NSRange) -> EditResult {
        guard span.upperBound < text.length, text.character(at: span.upperBound - 1) == LineSpan.newline else {
            return .keep(selection)
        }
        let below = LineSpan.contentRange(text, at: span.upperBound)
        let belowSpan = NSRange(location: below.location, length: min(below.length + 1, text.length - below.location))
        let swapped = swap(first: text.substring(with: span), second: text.substring(with: belowSpan))
        let change = TextChange(range: NSUnionRange(span, belowSpan), text: swapped)
        let delta = below.length + 1
        return EditResult(changes: [change], selection: shifted(selection, by: delta, in: text, change: change))
    }

    private static func swap(first: String, second: String) -> String {
        if second.hasSuffix("\n") {
            return second + first
        }
        return second + "\n" + String(first.dropLast())
    }

    private static func shifted(_ selection: NSRange, by delta: Int, in text: NSString, change: TextChange) -> NSRange {
        let length = text.length + change.delta
        let location = min(selection.location + delta, length)
        return NSRange(location: location, length: min(selection.length, length - location))
    }

    static func moveStatement(_ text: String, current: NSRange, other: NSRange, selection: NSRange) -> EditResult {
        guard current.length > 0, other.length > 0, NSIntersectionRange(current, other).length == 0 else {
            return .keep(selection)
        }
        let first = current.location < other.location ? current : other
        let second = current.location < other.location ? other : current
        guard first.upperBound <= second.location else {
            return .keep(selection)
        }
        let source = text as NSString
        let gap = NSRange(location: first.upperBound, length: second.location - first.upperBound)
        let swapped = source.substring(with: second) + source.substring(with: gap) + source.substring(with: first)
        let span = NSRange(location: first.location, length: second.upperBound - first.location)
        let change = TextChange(range: span, text: swapped)
        let delta = current.location < other.location ? second.length + gap.length : -(first.length + gap.length)
        return EditResult(changes: [change], selection: shifted(selection, by: delta, in: source, change: change))
    }

    static func newLineAfter(_ text: String, caret: Int, indent: String) -> EditResult {
        let source = text as NSString
        let end = LineSpan.lineEnd(source, at: caret)
        let inserted = "\n" + indent
        let change = TextChange(insert: inserted, at: end)
        return EditResult(changes: [change], selection: NSRange(location: end + inserted.utf16.count, length: 0))
    }

    static func newLineBefore(_ text: String, caret: Int, indent: String) -> EditResult {
        let source = text as NSString
        let start = LineSpan.lineStart(source, at: caret)
        let change = TextChange(insert: indent + "\n", at: start)
        return EditResult(changes: [change], selection: NSRange(location: start + indent.utf16.count, length: 0))
    }
}
