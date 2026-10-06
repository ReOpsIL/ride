enum GitSyncLabel {
    static func text(_ repo: GitRepoStatus?) -> String {
        guard let repo else {
            return ""
        }
        var parts: [String] = []
        if repo.ahead > 0 {
            parts.append("↑\(repo.ahead)")
        }
        if repo.behind > 0 {
            parts.append("↓\(repo.behind)")
        }
        return parts.isEmpty ? "" : " " + parts.joined(separator: " ")
    }
}
