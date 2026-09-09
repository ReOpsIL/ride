import Foundation

struct RecentProjects {
    private let maxEntries = 12

    func load() -> [URL] {
        guard let data = try? Data(contentsOf: fileURL()),
              let rows = try? JSONDecoder().decode([Row].self, from: data)
        else {
            return []
        }
        return rows.compactMap { row in
            if let bookmark = row.bookmark {
                var stale = false
                if let url = try? URL(
                    resolvingBookmarkData: bookmark,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                ) {
                    return url
                }
            }
            let url = URL(fileURLWithPath: row.path)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    func save(_ urls: [URL]) {
        let rows: [Row] = urls.prefix(maxEntries).map { url in
            let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            return Row(path: url.path, bookmark: bookmark)
        }
        let dir = fileURL().deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(rows) {
            try? data.write(to: fileURL(), options: .atomic)
        }
    }

    func adding(_ url: URL, to existing: [URL]) -> [URL] {
        let standardized = url.standardizedFileURL
        var next = existing.filter { $0.standardizedFileURL != standardized }
        next.insert(standardized, at: 0)
        if next.count > maxEntries {
            next = Array(next.prefix(maxEntries))
        }
        return next
    }

    private func fileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Ride/recent.json")
    }
}

private struct Row: Codable {
    var path: String
    var bookmark: Data?
}
