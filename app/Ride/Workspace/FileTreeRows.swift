import Foundation

struct FileTreeItem: Identifiable {
    let node: FileNode
    let depth: Int

    var id: URL { node.url }
}

enum FileTreeRows {
    static func visible(_ nodes: [FileNode], expanded: Set<URL>, depth: Int = 0) -> [FileTreeItem] {
        nodes.flatMap { node -> [FileTreeItem] in
            let item = FileTreeItem(node: node, depth: depth)
            guard node.isDirectory, expanded.contains(node.url) else {
                return [item]
            }
            return [item] + visible(node.children, expanded: expanded, depth: depth + 1)
        }
    }
}

enum TreeProjectMark: Equatable {
    case none
    case project
    case active

    init(path: String, roots: Set<String>, active: String?) {
        if path == active {
            self = .active
        } else if roots.contains(path) {
            self = .project
        } else {
            self = .none
        }
    }
}
