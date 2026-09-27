import AppKit

extension AppState {
    var selectedDirectory: URL? {
        selectedURL.map { WorkspaceFS.parentDir(for: $0, isDirectory: WorkspaceFS.isDirectory($0)) } ?? workspaceRoot
    }

    func runTreeAction(_ action: TreeAction, url: URL) {
        switch action {
        case .rename:
            renameItem(url)
        case .trash:
            trashItem(url)
        }
    }

    func handleTreeKey(keyCode: UInt16, modifiers: KeyModifiers) -> Bool {
        guard let url = selectedURL, let action = TreeModel.action(keyCode: keyCode, modifiers: modifiers) else {
            return false
        }
        runTreeAction(action, url: url)
        return true
    }

    func treeNewFile(in directory: URL) {
        guard let name = TreePrompt.newFileName(kind: projectModel.model?.kind) else {
            return
        }
        treeOperation("create \(name)") {
            let url = try TreeFileOps.createFile(named: name, in: directory)
            fileCreated(url)
            selectedURL = url
        }
    }

    func treeNewFolder(in directory: URL) {
        guard let name = TreePrompt.name(title: "New Folder", defaultName: "untitled") else {
            return
        }
        treeOperation("create \(name)") {
            treeChanged(try TreeFileOps.createFolder(named: name, in: directory))
        }
    }

    func treeDuplicate(_ url: URL) {
        treeOperation("duplicate \(url.lastPathComponent)") {
            treeChanged(try TreeFileOps.duplicate(url))
        }
    }

    private func renameItem(_ url: URL) {
        guard let name = TreePrompt.name(title: "Rename", defaultName: url.lastPathComponent), name != url.lastPathComponent else {
            return
        }
        treeOperation("rename \(url.lastPathComponent)") {
            let dest = try TreeFileOps.rename(url, to: name)
            RideEngineClient.shared.engine?.workspaceFileChanged(path: url.path)
            followMove(from: url, to: dest)
            treeChanged(dest)
        }
    }

    private func trashItem(_ url: URL) {
        TreeActions.trash(url) { [weak self] error in
            guard let self else {
                return
            }
            if let error {
                showNotice("Could not delete \(url.lastPathComponent): \(error.localizedDescription)")
                return
            }
            RideEngineClient.shared.engine?.workspaceFileChanged(path: url.path)
            buffers.filter { $0.fileURL.map { TreePath.contains(url, $0) } ?? false }.forEach(dropBuffer)
            forgetBreakpoints(under: url)
            if selectedURL.map({ TreePath.contains(url, $0) }) ?? false {
                selectedURL = nil
            }
            reloadTree()
        }
    }

    private func treeOperation(_ what: String, _ work: () throws -> Void) {
        do {
            try work()
        } catch {
            showNotice("Could not \(what): \(error.localizedDescription)")
        }
    }

    private func treeChanged(_ url: URL) {
        RideEngineClient.shared.engine?.workspaceFileChanged(path: url.path)
        selectedURL = url
        reloadTree()
    }
}
