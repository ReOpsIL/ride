import Foundation

enum FileIndex {
    static func list(root: URL, showHidden: Bool) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }
        var files: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if WorkspaceFS.skipName(url.lastPathComponent, showHidden: showHidden) {
                enumerator.skipDescendants()
                continue
            }
            if values?.isDirectory == true {
                continue
            }
            if values?.isRegularFile == true {
                files.append(url.standardizedFileURL)
            }
        }
        return files
    }

    static func matches(query: String, files: [URL], root: URL) -> [URL] {
        let parts = query
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
        if parts.isEmpty {
            return Array(files.prefix(40))
        }
        return files.filter { url in
            let rel = WorkspaceFS.relativePath(root: root, file: url).lowercased()
            return parts.allSatisfy { rel.contains($0) }
        }
        .prefix(40)
        .map { $0 }
    }
}
