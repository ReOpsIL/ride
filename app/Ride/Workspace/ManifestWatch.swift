import Foundation

enum ManifestWatch {
    static let names: Set<String> = [
        "Cargo.toml",
        "Cargo.lock",
        "CMakeLists.txt",
        "Makefile",
        "GNUmakefile",
        "compile_commands.json",
    ]

    static let generated: Set<String> = ["target", "build"]

    static func isManifest(_ path: String, root: URL) -> Bool {
        let name = (path as NSString).lastPathComponent
        guard names.contains(name) else {
            return false
        }
        let rel = WorkspaceFS.relativePath(root: root, file: URL(fileURLWithPath: path))
        let directories = rel.split(separator: "/").dropLast().map(String.init)
        return !directories.contains { generated.contains($0) }
    }

    static func touchesManifest(_ paths: [String], root: URL) -> Bool {
        paths.contains { isManifest($0, root: root) }
    }
}
