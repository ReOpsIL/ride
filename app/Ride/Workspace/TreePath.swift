import Foundation

enum TreePath {
    static func ancestors(of file: URL, root: URL) -> [URL] {
        let rootURL = root.standardizedFileURL
        let rel = WorkspaceFS.relativePath(root: rootURL, file: file)
        guard WorkspaceFS.contains(root: rootURL, file: file), rel != "." else {
            return []
        }
        let parts = rel.split(separator: "/").dropLast()
        var dir = rootURL
        return parts.map { part in
            dir = dir.appendingPathComponent(String(part)).standardizedFileURL
            return dir
        }
    }
}
