import Foundation

enum CargoWatch {
    static func isManifest(_ path: String, root: URL) -> Bool {
        let name = (path as NSString).lastPathComponent
        guard name == "Cargo.toml" || name == "Cargo.lock" else {
            return false
        }
        let rel = WorkspaceFS.relativePath(root: root, file: URL(fileURLWithPath: path))
        return !rel.split(separator: "/").contains("target")
    }

    static func touchesManifest(_ paths: [String], root: URL) -> Bool {
        paths.contains { isManifest($0, root: root) }
    }
}
