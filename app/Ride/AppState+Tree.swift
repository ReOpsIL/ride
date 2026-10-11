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
        var next = prefs
        edit(&next)
        next = next.clamped
        guard next != prefs else {
            return
        }
        let before = prefs
        prefs = next
        PreferencesStore.save(next)
        scheduleWorkspaceSave()
        if before.showHidden != next.showHidden {
            quickFiles = []
            reloadTree()
        }
        if before.theme != next.theme {
            applyTheme()
        } else if before.fontSize != next.fontSize {
            applyTerminalFont()
        }
    }

    func publishPrefs() {
        syncMenu()
        RideEngineClient.shared.setSemantic(prefs.semanticCompletion)
        prefsPublish?.cancel()
        let publish = DispatchWorkItem { [weak self] in
            self?.objectWillChange.send()
        }
        prefsPublish = publish
        DispatchQueue.main.async(execute: publish)
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
