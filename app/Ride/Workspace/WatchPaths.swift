import Foundation

struct WatchBatch: Equatable {
    var sources: [String]
    var gitChanged: Bool

    var isEmpty: Bool {
        sources.isEmpty && !gitChanged
    }
}

enum WatchPaths {
    static let ignoredDirectories: Set<String> = ["target"]
    static let gitDirectory = ".git"
    static let gitMarkers: Set<String> = ["HEAD", "refs", "packed-refs", "index"]

    static func classify(_ paths: [String], root: URL) -> WatchBatch {
        var batch = WatchBatch(sources: [], gitChanged: false)
        for path in paths {
            let parts = relativeParts(path, root: root)
            guard let first = parts.first, parts.count > 1 else {
                batch.sources.append(path)
                continue
            }
            if first == gitDirectory {
                batch.gitChanged = batch.gitChanged || gitMarkers.contains(parts[1])
            } else if !ignoredDirectories.contains(first) {
                batch.sources.append(path)
            }
        }
        return batch
    }

    private static func relativeParts(_ path: String, root: URL) -> [String] {
        let file = URL(fileURLWithPath: path)
        guard WorkspaceFS.contains(root: root, file: file) else {
            return []
        }
        return WorkspaceFS.relativePath(root: root, file: file).split(separator: "/").map(String.init)
    }
}
