import Foundation

struct ReportFile: Equatable {
    var url: URL
    var modified: Double

    var name: String {
        url.lastPathComponent
    }

    var isCrash: Bool {
        name.hasPrefix(ReportStore.crashPrefix)
    }
}

struct ReportStore {
    static let crashPrefix = "crash-"
    static let limit = 20

    let directory: URL

    func all() -> [ReportFile] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []
        let files: [ReportFile] = entries.compactMap { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true else {
                return nil
            }
            let date = values?.contentModificationDate ?? .distantPast
            return ReportFile(url: url, modified: date.timeIntervalSince1970)
        }
        return Self.sorted(files)
    }

    func new(since acknowledged: Double) -> [ReportFile] {
        all().filter { $0.modified > acknowledged }
    }

    func prune() {
        for file in Self.beyondLimit(all()) {
            try? FileManager.default.removeItem(at: file.url)
        }
    }

    func text(of files: [ReportFile]) -> String {
        files.map { file in
            let body = (try? String(contentsOf: file.url, encoding: .utf8)) ?? ""
            return "=== \(file.name) ===\n\(body)"
        }
        .joined(separator: "\n")
    }

    static func sorted(_ files: [ReportFile]) -> [ReportFile] {
        files.sorted { left, right in
            left.modified == right.modified ? left.name > right.name : left.modified > right.modified
        }
    }

    static func beyondLimit(_ files: [ReportFile]) -> [ReportFile] {
        let crashes = sorted(files).filter(\.isCrash)
        guard crashes.count > limit else {
            return []
        }
        return Array(crashes.dropFirst(limit))
    }

    static func noticeText(for files: [ReportFile]) -> String {
        files.contains(where: \.isCrash)
            ? "Ride crashed last time"
            : "Ride hit an internal error last time"
    }
}
