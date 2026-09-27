import Foundation

extension AppState {
    var relativePath: String {
        if let url = activeBuffer?.fileURL, let root = workspaceRoot {
            return WorkspaceFS.relativePath(root: root, file: url)
        }
        if let active = activeBuffer {
            return active.displayName
        }
        guard let root = workspaceRoot, let selected = selectedURL else {
            return "—"
        }
        return WorkspaceFS.relativePath(root: root, file: selected)
    }

    func reindex() {
        guard let root = workspaceRoot else {
            return
        }
        let name = root.lastPathComponent
        let started = IndexerProcess.run(project: root, indexDir: RideEngineClient.shared.indexDir, force: true) { [weak self] status in
            self?.showNotice(status == 0 ? "Reindexed \(name)" : "Reindex of \(name) failed (exit \(status))")
        }
        showNotice(started ? "Reindexing \(name)…" : "Could not start the indexer for \(name)", seconds: started ? 30 : 6)
    }

    func updatePrefs(_ edit: (inout Preferences) -> Void) {
        let before = prefs
        edit(&prefs)
        prefs = prefs.clamped
        PreferencesStore.save(prefs)
        scheduleWorkspaceSave()
        if before.showHidden != prefs.showHidden {
            quickFiles = []
            reloadTree()
        }
        if before.theme != prefs.theme {
            applyTheme()
        } else if before.fontSize != prefs.fontSize {
            applyTerminalFont()
        }
    }

    func reloadTree() {
        guard let root = workspaceRoot else {
            rootNodes = []
            return
        }
        rootNodes = WorkspaceFS.children(of: root, showHidden: prefs.showHidden)
        restoreExpanded(rootNodes)
    }

    private func restoreExpanded(_ nodes: [FileNode]) {
        for node in nodes where node.isDirectory && expanded.contains(node.url) {
            node.loadChildren()
            restoreExpanded(node.children)
        }
    }
}
