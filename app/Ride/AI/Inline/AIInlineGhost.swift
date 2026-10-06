import Foundation

struct AIInlineGhost: Equatable {
    let anchor: Int
    let text: String
    var consumed = 0

    var location: Int {
        anchor + consumed
    }

    var remaining: String {
        (text as NSString).substring(from: min(consumed, (text as NSString).length))
    }

    var lines: [String] {
        remaining.components(separatedBy: "\n")
    }

    func advanced(by typed: String) -> AIInlineGhost? {
        guard !typed.isEmpty, remaining.hasPrefix(typed) else {
            return nil
        }
        var next = self
        next.consumed += (typed as NSString).length
        return next.remaining.isEmpty ? nil : next
    }

    var nextChunk: String {
        let chars = Array(remaining)
        guard let first = chars.first else {
            return ""
        }
        var end = 0
        if first == "\n" {
            end = 1
            while end < chars.count, chars[end] == " " || chars[end] == "\t" {
                end += 1
            }
            return String(chars[..<end])
        }
        while end < chars.count, chars[end] == " " || chars[end] == "\t" {
            end += 1
        }
        guard end < chars.count, chars[end] != "\n" else {
            return String(chars[..<end])
        }
        let word = Self.isWord(chars[end])
        while end < chars.count, chars[end] != "\n", !chars[end].isWhitespace, Self.isWord(chars[end]) == word {
            end += 1
            if !word {
                break
            }
        }
        return String(chars[..<end])
    }

    static func cleaned(_ suggestion: String, lineBeforeCaret: String) -> String? {
        var text = suggestion
        let typed = lineBeforeCaret.trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty, text.hasPrefix(typed) {
            text = String(text.dropFirst(typed.count))
        }
        while let last = text.last, last.isWhitespace {
            text.removeLast()
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    private static func isWord(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "_"
    }
}
