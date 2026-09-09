import Foundation

enum IdentifierRange {
    static func at(_ text: NSString, index: Int) -> NSRange? {
        let length = text.length
        guard length > 0 else {
            return nil
        }
        var start = min(max(index, 0), length)
        if start == length || !isIdent(text.character(at: start)) {
            guard start > 0, isIdent(text.character(at: start - 1)) else {
                return nil
            }
            start -= 1
        }
        var end = start + 1
        while start > 0, isIdent(text.character(at: start - 1)) {
            start -= 1
        }
        while end < length, isIdent(text.character(at: end)) {
            end += 1
        }
        return NSRange(location: start, length: end - start)
    }

    static func isIdent(_ c: unichar) -> Bool {
        (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c > 127
    }
}
