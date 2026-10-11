import Foundation

extension AppState {
    func toggleWorkspaceMap() {
        showWorkspaceMap.toggle()
        guard showWorkspaceMap else { return }
        reloadWorkspaceMap(force: false)
    }

    func reloadWorkspaceMap(force: Bool) {
        guard showWorkspaceMap, let root = workspaceRoot else { return }
        workspaceMap.reload(root: root, force: force)
    }

    func pressMapNode(_ node: MapNode) {
        guard node.opens else { return }
        workspaceMap.enter(node.id)
    }

    func openMapFile(_ node: MapNode) {
        guard let path = node.path else { return }
        showWorkspaceMap = false
        openFile(URL(fileURLWithPath: path))
    }
}
