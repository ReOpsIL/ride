import Foundation

enum CompletionPosition: Equatable {
    case unknown
    case typePosition
    case valuePosition
    case memberAccess

    static let typeWords: Set<String> = ["as", "impl", "dyn", "struct", "enum", "trait", "type"]
    static let valueWords: Set<String> = ["return", "in", "if", "while", "match"]
    static let valueSymbols: Set<String> = ["=", "(", ",", "{", ";", "+", "-", "*", "/", "!", "==", "!=", "<=", ">=", "&&", "||", "=>", "[", "|"]

    static func detect(before text: String) -> CompletionPosition {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix(".") && !text.hasSuffix("..") {
            return .memberAccess
        }
        if trimmed.isEmpty {
            return .valuePosition
        }
        let tail = lastToken(trimmed)
        if tail == "&" || tail == "mut" {
            return detect(before: String(trimmed.dropLast(tail.count)))
        }
        if tail == ":" || tail == "->" || tail == "<" || typeWords.contains(tail) {
            return .typePosition
        }
        if valueSymbols.contains(tail) || valueWords.contains(tail) {
            return .valuePosition
        }
        return .unknown
    }

    private static func lastToken(_ s: String) -> String {
        let chars = Array(s)
        var i = chars.count
        if i == 0 {
            return ""
        }
        if isWord(chars[i - 1]) {
            while i > 0 && isWord(chars[i - 1]) {
                i -= 1
            }
            return String(chars[i...])
        }
        let two = i >= 2 ? String(chars[(i - 2)...]) : ""
        if ["->", "::", "==", "!=", "<=", ">=", "&&", "||", "=>", ".."].contains(two) {
            return two
        }
        return String(chars[i - 1])
    }

    private static func isWord(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "_"
    }
}
