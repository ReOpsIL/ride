import Foundation

struct ProjectFindMatch: Identifiable, Hashable {
    let id: Int
    let file: URL
    let line: Int
    let byte: UInt32
    let preview: String
}

struct ProjectFindResult {
    let matches: [ProjectFindMatch]
    let hits: [FileHit]
    let truncated: Bool

    static let empty = ProjectFindResult(matches: [], hits: [], truncated: false)
}

enum ProjectFind {
    static let maxBytes = 1_048_576
    static let cap = 2000
    static let previewLength = 160

    static func search(
        root: URL,
        query: String,
        showHidden: Bool,
        options: FindOptions = .defaults,
        cap: Int = cap
    ) -> ProjectFindResult {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else {
            return .empty
        }
        var matches: [ProjectFindMatch] = []
        var hits: [FileHit] = []
        let files = FileIndex.list(root: root, showHidden: showHidden)
            .sorted { $0.path < $1.path }
        for url in files {
            guard let text = readText(url) else {
                continue
            }
            let ranges = FindMatcher.matches(in: text, query: needle, options: options)
            if ranges.isEmpty {
                continue
            }
            var taken: [NSRange] = []
            for range in ranges {
                matches.append(makeMatch(text: text, range: range, file: url, id: matches.count))
                taken.append(range)
                if matches.count >= cap {
                    hits.append(FileHit(file: url, text: text, ranges: taken))
                    return ProjectFindResult(matches: matches, hits: hits, truncated: true)
                }
            }
            hits.append(FileHit(file: url, text: text, ranges: taken))
        }
        return ProjectFindResult(matches: matches, hits: hits, truncated: false)
    }

    private static func makeMatch(text: String, range: NSRange, file: URL, id: Int) -> ProjectFindMatch {
        let utf8 = Utf16.utf8Offset(in: text, utf16: range.location)
        let (row, _) = Utf16.point(in: text, utf8: utf8)
        let ns = text as NSString
        let lineRange = ns.lineRange(for: NSRange(location: range.location, length: 0))
        let line = ns.substring(with: lineRange).trimmingCharacters(in: .newlines)
        return ProjectFindMatch(
            id: id,
            file: file,
            line: Int(row) + 1,
            byte: UInt32(utf8),
            preview: preview(Substring(line))
        )
    }

    static func readText(_ url: URL) -> String? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= maxBytes,
              let data = try? Data(contentsOf: url),
              !data.prefix(8192).contains(0)
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func preview(_ line: Substring) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return String(trimmed.prefix(previewLength))
    }
}
