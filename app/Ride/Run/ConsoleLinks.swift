import Foundation

struct ConsoleLink: Equatable {
    var path: String
    var line: Int
    var column: Int?
    var start: Int
    var length: Int
}

enum ConsoleLinks {
    private static let pattern = "([A-Za-z0-9_./+~-]*[A-Za-z0-9_+~-]\\.[A-Za-z][A-Za-z0-9_]*):([0-9]+)(?::([0-9]+))?"

    private static let regex: NSRegularExpression? = try? NSRegularExpression(pattern: pattern)

    static func links(in text: String) -> [ConsoleLink] {
        guard let regex else {
            return []
        }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { match in
            guard let path = group(match, 1, ns), let line = group(match, 2, ns).flatMap({ Int($0) }), line > 0 else {
                return nil
            }
            let column = group(match, 3, ns).flatMap { Int($0) }
            return ConsoleLink(
                path: path,
                line: line,
                column: column,
                start: match.range.location,
                length: match.range.length
            )
        }
    }

    static func absolutePath(_ link: ConsoleLink, root: String?) -> String {
        let path = (link.path as NSString).expandingTildeInPath
        if path.hasPrefix("/") {
            return (path as NSString).standardizingPath
        }
        guard let root, !root.isEmpty else {
            return path
        }
        return ((root as NSString).appendingPathComponent(path) as NSString).standardizingPath
    }

    private static func group(_ match: NSTextCheckingResult, _ index: Int, _ text: NSString) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound else {
            return nil
        }
        return text.substring(with: range)
    }
}
