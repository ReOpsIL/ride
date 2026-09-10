import Foundation

enum SmartIndent {
    static let openers: Set<Character> = ["{", "(", "["]
    static let closers: Set<Character> = ["}", ")", "]"]

    static func newline(_ text: String, caret: Int, unit: String, lineComment: String? = nil) -> EditResult {
        let source = text as NSString
        let start = LineSpan.lineStart(source, at: caret)
        let before = source.substring(with: NSRange(location: start, length: caret - start))
        let indent = String(before.prefix { $0 == " " || $0 == "\t" })
        let trimmed = before.trimmingCharacters(in: .whitespaces)
        let insertion: String
        let caretOffset: Int
        if let prefix = CommentPrefix.continuation(source, lineStart: start, trimmed: trimmed, lineComment: lineComment) {
            insertion = "\n" + indent + prefix
            caretOffset = insertion.utf16.count
        } else if opensBlock(trimmed, unit: unit) {
            insertion = "\n" + indent + unit
            caretOffset = insertion.utf16.count
            if let last = trimmed.last, let close = closer(for: last), nextCharacter(source, at: caret) == close {
                return EditResult(
                    changes: [TextChange(insert: insertion + "\n" + indent, at: caret)],
                    selection: NSRange(location: caret + caretOffset, length: 0)
                )
            }
        } else {
            insertion = "\n" + indent
            caretOffset = insertion.utf16.count
        }
        return EditResult(changes: [TextChange(insert: insertion, at: caret)], selection: NSRange(location: caret + caretOffset, length: 0))
    }

    static func opensBlock(_ trimmed: String, unit: String) -> Bool {
        guard let last = trimmed.last else {
            return false
        }
        return openers.contains(last) || trimmed.hasSuffix("=>") || (unit == "\t" && last == ":")
    }

    static func closer(for opener: Character) -> Character? {
        switch opener {
        case "{": return "}"
        case "(": return ")"
        case "[": return "]"
        default: return nil
        }
    }

    static func opener(for closer: Character) -> Character? {
        switch closer {
        case "}": return "{"
        case ")": return "("
        case "]": return "["
        default: return nil
        }
    }

    static func nextCharacter(_ text: NSString, at location: Int) -> Character? {
        guard location < text.length else {
            return nil
        }
        return character(text, at: location)
    }

    static func character(_ text: NSString, at location: Int) -> Character {
        Character(Unicode.Scalar(text.character(at: location)) ?? " ")
    }

    static func closingBrace(_ text: String, caret: Int, typed: String) -> EditResult? {
        let source = text as NSString
        let line = LineSpan.contentRange(source, at: caret)
        guard let close = typed.first, typed.count == 1, let open = opener(for: close),
              LineSpan.isBlank(source, line: line),
              let match = matchingOpener(source, before: line.location, open: open, close: close)
        else {
            return nil
        }
        let indent = LineSpan.indentation(source, line: LineSpan.contentRange(source, at: match))
        let change = TextChange(range: line, text: indent + typed)
        return EditResult(changes: [change], selection: NSRange(location: line.location + change.text.utf16.count, length: 0))
    }

    private static func matchingOpener(_ text: NSString, before location: Int, open: Character, close: Character) -> Int? {
        var depth = 0
        var index = location
        while index > 0 {
            index -= 1
            let unit = character(text, at: index)
            if unit == close {
                depth += 1
            } else if unit == open {
                if depth == 0 {
                    return index
                }
                depth -= 1
            }
        }
        return nil
    }
}
