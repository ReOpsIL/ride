import Foundation

enum CommentPrefix {
    static func continuation(_ text: NSString, lineStart: Int, trimmed: String, lineComment: String?) -> String? {
        for doc in ["///", "//!"] where trimmed.hasPrefix(doc) {
            return doc + " "
        }
        if let token = lineComment, token == "#", trimmed.hasPrefix("#") {
            return "# "
        }
        if trimmed.hasPrefix("/*"), !trimmed.contains("*/") {
            return " * "
        }
        if trimmed.hasPrefix("*"), !trimmed.hasPrefix("*/"), insideBlock(text, lineStart: lineStart) {
            return "* "
        }
        return nil
    }

    private static func insideBlock(_ text: NSString, lineStart: Int) -> Bool {
        var line = LineSpan.contentRange(text, at: lineStart)
        while let previous = LineSpan.previousNonBlank(text, before: line) {
            let content = text.substring(with: previous).trimmingCharacters(in: .whitespaces)
            if content.hasPrefix("/*") {
                return !content.contains("*/")
            }
            if !content.hasPrefix("*") || content.hasPrefix("*/") {
                return false
            }
            line = previous
        }
        return false
    }
}
