import Foundation

struct GitTreeMarks: Equatable {
    static let empty = GitTreeMarks(files: [:])

    let files: [String: GitChangeKind]
    let dirs: Set<String>

    init(files: [String: GitChangeKind]) {
        self.files = files
        dirs = GitPathMap.parents(of: Set(files.keys))
    }

    init(status: GitRepoStatus, map: GitPathMap) {
        var files: [String: GitChangeKind] = [:]
        for change in status.changes {
            if let relative = map.workspaceRelative(change.path), let kind = change.shownKind {
                files[relative] = kind
            }
        }
        self.init(files: files)
    }

    func kind(relative: String) -> GitChangeKind? {
        files[relative]
    }

    func containsChange(directory relative: String) -> Bool {
        relative == "." ? !files.isEmpty : dirs.contains(relative)
    }
}
