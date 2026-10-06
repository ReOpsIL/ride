import AppKit

extension AppState {
    func watchWorkspaceQuit() {
        stopRunOnWorkspaceChange()
        stopTerminalsOnWorkspaceChange()
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopRun()
            self?.terminals.closeAll()
            self?.flushWorkspace()
        }
    }

    var canPersistWorkspace: Bool {
        persistLayout && !DemoLaunch.isDemo && workspaceRoot != nil
    }

    func workspaceRootDidChange() {
        workspaceStore.cancelPending()
    }

    func scheduleWorkspaceSave() {
        guard !restoringWorkspace, canPersistWorkspace, let root = workspaceRoot else {
            return
        }
        workspaceStore.scheduleSave(root: root) { [weak self] in
            self?.captureWorkspace()
        }
    }

    func flushWorkspace() {
        guard canPersistWorkspace, let root = workspaceRoot else {
            return
        }
        workspaceStore.save(captureWorkspace(), root: root)
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Open a Cargo project or folder"
        if let url = ModalPanels.chooseURL(panel) {
            open(url)
        }
    }

    @discardableResult
    func open(_ url: URL) -> Bool {
        guard releaseWorkspace() else {
            return false
        }
        restoringWorkspace = true
        workspaceRoot = url.standardizedFileURL
        cursorLine = 1
        cursorColumn = 1
        recent = recents.adding(url, to: recent)
        if !DemoLaunch.isDemo {
            recents.save(recent)
        }
        reloadTree()
        watcher.start(path: url.path)
        RideEngineClient.shared.openWorkspace(url) { [weak self] in
            self?.indexOpenBuffers()
        }
        projectModel.load(workspace: url)
        git.refresh(root: url, delay: 0)
        restoreOpenedWorkspace()
        restoringWorkspace = false
        scheduleWorkspaceSave()
        return true
    }

    func closeWorkspace() {
        if releaseWorkspace() {
            workspaceRoot = nil
        }
    }

    private func releaseWorkspace() -> Bool {
        flushWorkspace()
        guard closeAll() else {
            return false
        }
        stopRun()
        terminals.closeAll()
        watcher.stop()
        RideEngineClient.shared.closeWorkspace()
        CompletionSession.shared.reset()
        overlay = nil
        rootNodes = []
        selectedURL = nil
        expanded = []
        quickFiles = []
        git.clear()
        gitChanges.reset()
        projectModel.clear()
        return true
    }

    func confirmQuit() -> Bool {
        buffers.filter(\.isDirty).allSatisfy { buffer in
            activeID = buffer.id
            return confirmClose(buffer)
        }
    }

    func restoreOpenedWorkspace() {
        guard !DemoLaunch.isDemo, let root = workspaceRoot, let saved = workspaceStore.load(root: root) else {
            return
        }
        restoreWorkspace(saved)
    }

    func closeFrontmost() {
        if let key = NSApp.keyWindow, MainWindow.isOther(key) {
            key.performClose(nil)
            return
        }
        if let id = activeID {
            closeBuffer(id)
        }
    }
}
