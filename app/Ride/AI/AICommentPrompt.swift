import Foundation

enum AICommentPrompt {
    static func extract(_ text: String, caret: Int, tokens: CommentTokens) -> String? {
        let lines = text.components(separatedBy: "\n")
        var index = 0
        var offset = 0
        for (i, line) in lines.enumerated() {
            let end = offset + line.utf16.count
            if caret <= end {
                index = i
                break
            }
            offset = end + 1
            index = i
        }
        if body(lines[index], tokens: tokens) != nil {
            return joined(lines, around: index, tokens: tokens)
        }
        var above = index - 1
        while above >= 0, lines[above].trimmingCharacters(in: .whitespaces).isEmpty {
            above -= 1
        }
        guard above >= 0, body(lines[above], tokens: tokens) != nil else {
            return nil
        }
        return joined(lines, around: above, tokens: tokens)
    }

    private static func joined(_ lines: [String], around index: Int, tokens: CommentTokens) -> String? {
        var start = index
        while start > 0, body(lines[start - 1], tokens: tokens) != nil {
            start -= 1
        }
        var end = index
        while end + 1 < lines.count, body(lines[end + 1], tokens: tokens) != nil {
            end += 1
        }
        let parts = lines[start ... end].compactMap { body($0, tokens: tokens) }.filter { !$0.isEmpty }
        let text = parts.joined(separator: "\n")
        return text.isEmpty ? nil : text
    }

    static func body(_ line: String, tokens: CommentTokens) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let open = tokens.blockOpen, let close = tokens.blockClose {
            var inner = trimmed
            let closed = inner.hasSuffix(close)
            if closed {
                inner = String(inner.dropLast(close.count)).trimmingCharacters(in: .whitespaces)
            }
            if inner.hasPrefix(open) {
                return String(inner.dropFirst(open.count)).trimmingCharacters(in: .whitespaces)
            }
            if inner == "*" || inner.hasPrefix("* ") {
                return String(inner.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            if closed {
                return inner
            }
        }
        if let token = tokens.line, trimmed.hasPrefix(token) {
            var rest = trimmed.dropFirst(token.count)
            while let first = rest.first, first == "/" || first == "!" {
                rest = rest.dropFirst()
            }
            return rest.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}
