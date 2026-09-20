import Foundation

enum WorkspaceRootFinder {
    static let markers = ["Cargo.toml", "CMakeLists.txt", "Makefile", "compile_commands.json"]

    static func root(for file: URL, fileExists: (String) -> Bool) -> URL {
        let directory = file.deletingLastPathComponent().standardizedFileURL
        var candidate = directory
        while true {
            if markers.contains(where: { fileExists(candidate.appendingPathComponent($0).path) }) {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent().standardizedFileURL
            if parent.path == candidate.path {
                return directory
            }
            candidate = parent
        }
    }

    static func root(for file: URL) -> URL {
        root(for: file) { FileManager.default.fileExists(atPath: $0) }
    }
}
