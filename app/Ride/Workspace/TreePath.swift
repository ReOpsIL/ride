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

    static func moved(_ path: String, from source: String, to dest: String) -> String? {
        guard path != source else {
            return dest
        }
        let prefix = source.hasSuffix("/") ? source : source + "/"
        guard path.hasPrefix(prefix) else {
            return nil
        }
        let base = dest.hasSuffix("/") ? String(dest.dropLast()) : dest
        return base + "/" + path.dropFirst(prefix.count)
    }

    static func contains(_ root: URL, _ url: URL) -> Bool {
        moved(url.standardizedFileURL.path, from: root.standardizedFileURL.path, to: "") != nil
    }

    static func movedURL(_ url: URL, from source: URL, to dest: URL) -> URL? {
        moved(url.standardizedFileURL.path, from: source.standardizedFileURL.path, to: dest.standardizedFileURL.path)
            .map { URL(fileURLWithPath: $0) }
    }
}
