import Foundation

struct GitPathMap: Equatable {
    let repoRoot: URL
    let workspace: URL
    let prefix: String?

    init(repoRoot: String, workspace: URL) {
        self.repoRoot = URL(fileURLWithPath: repoRoot).standardizedFileURL
        self.workspace = workspace.standardizedFileURL
        let real = self.repoRoot.resolvingSymlinksInPath().path
        let inside = self.workspace.resolvingSymlinksInPath().path
        if inside == real {
            prefix = ""
        } else if inside.hasPrefix(real + "/") {
            prefix = String(inside.dropFirst(real.count + 1)) + "/"
        } else {
            prefix = nil
        }
    }

    func workspaceRelative(_ repoPath: String) -> String? {
        guard let prefix, repoPath.hasPrefix(prefix) else {
            return nil
        }
        return String(repoPath.dropFirst(prefix.count))
    }

    func url(_ repoPath: String) -> URL {
        guard let relative = workspaceRelative(repoPath) else {
            return repoRoot.appendingPathComponent(repoPath)
        }
        return workspace.appendingPathComponent(relative)
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
