import Foundation

enum MatchHighlight {
    static func ranges(in text: String, query: String) -> [NSRange] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty, !text.isEmpty else {
            return []
        }
        let ns = text as NSString
        let whole = ns.range(of: needle, options: .caseInsensitive)
        if whole.location != NSNotFound {
            return [whole]
        }
        var out: [NSRange] = []
        var cursor = 0
        for ch in needle.lowercased() where !ch.isWhitespace {
            let rest = NSRange(location: cursor, length: ns.length - cursor)
            let found = ns.range(of: String(ch), options: .caseInsensitive, range: rest)
            if found.location == NSNotFound {
                return []
            }
            if let last = out.last, NSMaxRange(last) == found.location {
                out[out.count - 1] = NSRange(location: last.location, length: last.length + found.length)
            } else {
                out.append(found)
            }
            cursor = NSMaxRange(found)
        }
        return out
    }

    static func substrings(in text: String, query: String) -> [NSRange] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else {
            return []
        }
        let ns = text as NSString
        var out: [NSRange] = []
        var cursor = 0
        while cursor < ns.length {
            let found = ns.range(of: needle, options: .caseInsensitive, range: NSRange(location: cursor, length: ns.length - cursor))
            if found.location == NSNotFound {
                break
            }
            out.append(found)
            cursor = NSMaxRange(found)
        }
        return out
    }
}
