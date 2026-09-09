import Foundation

struct CompletionToken {
    var prefix: String
    var replaceUtf16: Int
    var replaceUtf8: UInt32
    var cursorUtf8: UInt32
    var currentCrate: String?
    var currentModule: String?
    var mode: QueryMode
    var position: CompletionPosition
}

enum CompletionTokenizer {
    static func token(in text: String, utf16 caret: Int) -> CompletionToken? {
        if inStringOrComment(text, utf16: caret) {
            return nil
        }
        let ns = text as NSString
        let loc = min(max(caret, 0), ns.length)
        var start = loc
        while start > 0 {
            let ch = ns.substring(with: NSRange(location: start - 1, length: 1))
            if isPathChar(ch) {
                start -= 1
            } else {
                break
            }
        }
        let raw = ns.substring(with: NSRange(location: start, length: loc - start))
        if raw.isEmpty {
            return nil
        }
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        let segs = parts.filter { $0 != "" }
        let prefix: String
        if raw.hasSuffix(":") {
            prefix = ""
        } else {
            prefix = segs.last ?? raw
        }
        if prefix.isEmpty {
            return nil
        }
        var crate: String?
        var module: String?
        var mode = QueryMode.bufferLocal
        if segs.count >= 2 {
            crate = segs[0]
            if segs.count >= 3 {
                module = segs.dropLast().joined(separator: "::")
            } else {
                module = segs[0]
            }
            mode = .items
        } else if prefix.count >= 3 {
            mode = .items
        }
        let position = CompletionPosition.detect(before: ns.substring(to: start))
        let replaceUtf8 = UInt32(Utf16.utf8Offset(in: text, utf16: loc - prefix.utf16.count))
        let cursorUtf8 = UInt32(Utf16.utf8Offset(in: text, utf16: loc))
        return CompletionToken(
            prefix: prefix,
            replaceUtf16: loc - prefix.utf16.count,
            replaceUtf8: replaceUtf8,
            cursorUtf8: cursorUtf8,
            currentCrate: crate,
            currentModule: module,
            mode: mode,
            position: position
        )
    }

    static func inStringOrComment(_ text: String, utf16 caret: Int) -> Bool {
        let ns = text as NSString
        let loc = min(max(caret, 0), ns.length)
        let prefix = ns.substring(to: loc)
        var i = prefix.startIndex
        var state = 0
        while i < prefix.endIndex {
            let c = prefix[i]
            let next = prefix.index(after: i)
            if state == 0 {
                if c == "/" && next < prefix.endIndex && prefix[next] == "/" {
                    state = 1
                    i = prefix.index(after: next)
                    continue
                }
                if c == "/" && next < prefix.endIndex && prefix[next] == "*" {
                    state = 2
                    i = prefix.index(after: next)
                    continue
                }
                if c == "\"" {
                    state = 3
                    i = next
                    continue
                }
                if c == "'" {
                    state = 4
                    i = next
                    continue
                }
            } else if state == 1 {
                if c == "\n" {
                    state = 0
                }
            } else if state == 2 {
                if c == "*" && next < prefix.endIndex && prefix[next] == "/" {
                    state = 0
                    i = prefix.index(after: next)
                    continue
                }
            } else if state == 3 {
                if c == "\\" && next < prefix.endIndex {
                    i = prefix.index(after: next)
                    continue
                }
                if c == "\"" {
                    state = 0
                }
            } else if state == 4 {
                if c == "\\" && next < prefix.endIndex {
                    i = prefix.index(after: next)
                    continue
                }
                if c == "'" {
                    state = 0
                }
            }
            i = next
        }
        return state != 0
    }

    private static func isPathChar(_ s: String) -> Bool {
        guard let c = s.unicodeScalars.first else {
            return false
        }
        return CharacterSet.alphanumerics.contains(c) || c == "_" || c == ":"
    }
}
