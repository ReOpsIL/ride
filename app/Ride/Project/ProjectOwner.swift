import Foundation

enum ProjectOwner {
    static func owner(of path: String, roots: [String]) -> Int? {
        roots.indices
            .filter { contains(root: roots[$0], path: path) }
            .max { roots[$0].count < roots[$1].count }
    }

    static func title(root: String, workspace: String) -> String {
        guard root != workspace, root.hasPrefix(workspace + "/") else {
            return (root as NSString).lastPathComponent
        }
        return String(root.dropFirst(workspace.count + 1))
    }

    private static func contains(root: String, path: String) -> Bool {
        path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }
}
