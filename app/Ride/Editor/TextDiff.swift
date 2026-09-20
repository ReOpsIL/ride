import Foundation

enum TextDiff {
    static func minimalEdit(from old: String, to new: String) -> (range: NSRange, text: String)? {
        let a = old as NSString
        let b = new as NSString
        guard !a.isEqual(to: new) else {
            return nil
        }
        let prefix = wholeScalarPrefix(a, b)
        let suffix = wholeScalarSuffix(a, b, prefix: prefix)
        let range = NSRange(location: prefix, length: a.length - suffix - prefix)
        let text = b.substring(with: NSRange(location: prefix, length: b.length - suffix - prefix))
        return (range, text)
    }

    private static func wholeScalarPrefix(_ a: NSString, _ b: NSString) -> Int {
        var count = 0
        let limit = min(a.length, b.length)
        while count < limit, a.character(at: count) == b.character(at: count) {
            count += 1
        }
        while count > 0, isLeading(a.character(at: count - 1)) {
            count -= 1
        }
        return count
    }

    private static func wholeScalarSuffix(_ a: NSString, _ b: NSString, prefix: Int) -> Int {
        var count = 0
        let limit = min(a.length, b.length) - prefix
        while count < limit, a.character(at: a.length - 1 - count) == b.character(at: b.length - 1 - count) {
            count += 1
        }
        while count > 0, isTrailing(a.character(at: a.length - count)) {
            count -= 1
        }
        return count
    }

    private static func isLeading(_ unit: unichar) -> Bool {
        (0xD800...0xDBFF).contains(unit)
    }

    private static func isTrailing(_ unit: unichar) -> Bool {
        (0xDC00...0xDFFF).contains(unit)
    }
}
