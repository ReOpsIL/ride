import Foundation

enum GitStatus {
    static func parse(porcelain: String) -> Set<String> {
        var out = Set<String>()
        for line in porcelain.split(separator: "\n") {
            guard line.count > 3 else {
                continue
            }
            var path = String(line.dropFirst(3))
            if let arrow = path.range(of: " -> ") {
                path = String(path[arrow.upperBound...])
            }
            if path.count >= 2, path.hasPrefix("\""), path.hasSuffix("\"") {
                path = String(path.dropFirst().dropLast())
            }
            if path.hasSuffix("/") {
                path.removeLast()
            }
            out.insert(path)
        }
        return out
    }

    static func parents(of paths: Set<String>) -> Set<String> {
        var dirs = Set<String>()
        for path in paths {
            var parts = Array(path.split(separator: "/").dropLast())
            while !parts.isEmpty {
                dirs.insert(parts.joined(separator: "/"))
                parts.removeLast()
            }
        }
        return dirs
    }
}
