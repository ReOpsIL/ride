import Foundation

enum SiblingSource {
    static let headers = ["h", "hpp", "hh", "hxx", "h++", "inl", "ipp", "tpp"]
    static let sources = ["c", "cpp", "cc", "cxx", "c++", "m", "mm"]
    static let dirSwaps: [(String, String)] = [("include", "src"), ("src", "include"), ("inc", "src"), ("src", "inc")]

    static func candidates(for url: URL) -> [URL] {
        let ext = url.pathExtension.lowercased()
        let partners: [String]
        if headers.contains(ext) {
            partners = sources
        } else if sources.contains(ext) {
            partners = headers
        } else {
            return []
        }
        let base = url.deletingPathExtension()
        var dirs = [base.deletingLastPathComponent()]
        for (from, to) in dirSwaps {
            dirs.append(contentsOf: swapped(base.deletingLastPathComponent(), from: from, to: to))
        }
        var out: [URL] = []
        for dir in dirs {
            for partner in partners {
                out.append(dir.appendingPathComponent(base.lastPathComponent).appendingPathExtension(partner))
            }
        }
        return out
    }

    static func existing(for url: URL, exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL? {
        candidates(for: url).first(where: exists)
    }

    private static func swapped(_ dir: URL, from: String, to: String) -> [URL] {
        var parts = dir.pathComponents
        var out: [URL] = []
        for (i, part) in parts.enumerated().reversed() where part == from {
            parts[i] = to
            out.append(URL(fileURLWithPath: parts.joined(separator: "/").replacingOccurrences(of: "//", with: "/")))
            parts[i] = from
        }
        return out
    }
}
