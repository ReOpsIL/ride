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
    let truncated: Bool

    static let empty = ProjectFindResult(matches: [], truncated: false)
}

enum ProjectFind {
    static let maxBytes = 1_048_576
    static let cap = 2000
    static let previewLength = 160

    static func search(root: URL, query: String, showHidden: Bool, cap: Int = cap) -> ProjectFindResult {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else {
            return .empty
        }
        var out: [ProjectFindMatch] = []
        let files = FileIndex.list(root: root, showHidden: showHidden)
            .sorted { $0.path < $1.path }
        for url in files {
            guard let text = readText(url) else {
                continue
            }
            if scan(text, needle: needle, file: url, into: &out, cap: cap) {
                return ProjectFindResult(matches: out, truncated: true)
            }
        }
        return ProjectFindResult(matches: out, truncated: false)
    }

    static func scan(_ text: String, needle: String, file: URL, into out: inout [ProjectFindMatch], cap: Int) -> Bool {
        var byte = 0
        var number = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            number += 1
            if line.lowercased().contains(needle) {
                out.append(ProjectFindMatch(
                    id: out.count,
                    file: file,
                    line: number,
                    byte: UInt32(byte),
                    preview: preview(line)
                ))
                if out.count >= cap {
                    return true
                }
            }
            byte += line.utf8.count + 1
        }
        return false
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
