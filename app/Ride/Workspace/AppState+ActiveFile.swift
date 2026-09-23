import Foundation

extension AppState {
    func activeFileDidChange() {
        let url = activeBuffer?.fileURL
        guard url != followedFileURL else {
            return
        }
        followedFileURL = url
        selectedURL = url
        projectModel.focus(file: url)
        if let url {
            revealInTree(url)
        }
    }

    func revealInTree(_ url: URL) {
        var nodes = rootNodes
        var opened: [URL] = []
        for dir in workspaceRoot.map({ TreePath.ancestors(of: url, root: $0) }) ?? [] {
            guard let node = nodes.first(where: { $0.url == dir }) else {
                break
            }
            node.loadChildren()
            opened.append(dir)
            nodes = node.children
        }
        if !expanded.isSuperset(of: opened) {
            expanded.formUnion(opened)
        }
    }

    var activeProjectRoot: URL? {
        projectModel.model.map { URL(fileURLWithPath: $0.root) } ?? workspaceRoot
    }

    func projectRoot(for file: URL?) -> URL? {
        file.flatMap(projectModel.owner(of:)).map { URL(fileURLWithPath: $0.root) } ?? workspaceRoot
    }
}
