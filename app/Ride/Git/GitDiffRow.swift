import Foundation

struct GitDiffRow: Identifiable {
    enum Content {
        case hunk(GitHunk)
        case line(GitDiffLine)
    }

    let id: Int
    let content: Content

    static func rows(_ diff: GitFileDiff) -> [GitDiffRow] {
        var out: [GitDiffRow] = []
        for hunk in diff.hunks {
            out.append(GitDiffRow(id: out.count, content: .hunk(hunk)))
            for line in hunk.lines {
                out.append(GitDiffRow(id: out.count, content: .line(line)))
            }
        }
        return out
    }
}
