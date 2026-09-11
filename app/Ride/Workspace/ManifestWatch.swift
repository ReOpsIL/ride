import Foundation

struct ManifestChange: Equatable {
    var reloadProject: Bool
    var reindexCargo: Bool
}

enum ManifestWatch {
    static let names: Set<String> = [
        "Cargo.toml",
        "Cargo.lock",
        "CMakeLists.txt",
        "Makefile",
        "GNUmakefile",
        "compile_commands.json",
    ]

    static let cargoNames: Set<String> = ["Cargo.toml", "Cargo.lock"]

    static func isManifest(_ path: String, root: URL) -> Bool {
        let name = (path as NSString).lastPathComponent
        return names.contains(name) && isVisible(path, root: root)
    }

    static func isCargoManifest(_ path: String, root: URL) -> Bool {
        let name = (path as NSString).lastPathComponent
        return cargoNames.contains(name) && isVisible(path, root: root)
    }

    static func touchesManifest(_ paths: [String], root: URL) -> Bool {
        paths.contains { isManifest($0, root: root) }
    }

    static func change(_ paths: [String], root: URL) -> ManifestChange {
        ManifestChange(
            reloadProject: touchesManifest(paths, root: root),
            reindexCargo: paths.contains { isCargoManifest($0, root: root) }
        )
    }

    private static func isVisible(_ path: String, root: URL) -> Bool {
        let rel = WorkspaceFS.relativePath(root: root, file: URL(fileURLWithPath: path))
        let directories = rel.split(separator: "/").dropLast().map(String.init)
        guard !directories.contains("target") else {
            return false
        }
        guard let build = directories.firstIndex(of: "build") else {
            return true
        }
        return build == directories.count - 1
    }
}
