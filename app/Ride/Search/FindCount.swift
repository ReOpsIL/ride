import Foundation

enum FindCount {
    static func matches(in text: String, query: String) -> [NSRange] {
        guard !query.isEmpty else {
            return []
        }
        let ns = text as NSString
        var out: [NSRange] = []
        var start = 0
        while start < ns.length {
            let found = ns.range(of: query, options: .caseInsensitive, range: NSRange(location: start, length: ns.length - start))
            if found.location == NSNotFound {
                break
            }
            out.append(found)
            start = found.location + max(found.length, 1)
        }
        return out
    }

    static func label(current: NSRange?, in text: String, query: String) -> String? {
        let all = matches(in: text, query: query)
        if query.isEmpty {
            return nil
        }
        if all.isEmpty {
            return "No results"
        }
        if let current, let index = all.firstIndex(where: { $0.location == current.location }) {
            return "\(index + 1) of \(all.count)"
        }
        return "\(all.count)"
    }
}
