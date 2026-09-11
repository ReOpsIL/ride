import AppKit

extension AppState {
    func watchWorkspaceQuit() {
        stopRunOnWorkspaceChange()
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.runOutput.stop()
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
        workspaceStore.scheduleSave(captureWorkspace(), root: root)
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
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        open(url)
    }

    func open(_ url: URL) {
        runOutput.stop()
        flushWorkspace()
        restoringWorkspace = true
        workspaceRoot = url.standardizedFileURL
        selectedURL = nil
        for buffer in buffers {
            SessionService.shared.close(buffer)
        }
        buffers = []
        paneLayout = PaneLayout()
        splitLayout = SplitLayout()
        cursorLine = 1
        cursorColumn = 1
        expanded = []
        recent = recents.adding(url, to: recent)
        recents.save(recent)
        quickFiles = []
        showQuickOpen = false
        CompletionSession.shared.reset()
        reloadTree()
        watcher.start(path: url.path)
        RideEngineClient.shared.openWorkspace(url)
        projectModel.load(root: url)
        git.clear()
        git.refresh(root: url, delay: 0)
        restoreOpenedWorkspace()
        restoringWorkspace = false
        scheduleWorkspaceSave()
    }

    func restoreOpenedWorkspace() {
        guard !DemoLaunch.isDemo, let root = workspaceRoot, let saved = workspaceStore.load(root: root) else {
            return
        }
        restoreWorkspace(saved)
    }

    func captureWorkspace() -> WorkspaceState {
        if !restoringWorkspace, let view = EditorPanes.shared.focusedView, let buffer = activeBuffer, buffer.id == activeID {
            buffer.capture(view)
        }
        return WorkspaceState(
            tabs: buffers.compactMap(tabState(of:)),
            focusedPath: activeBuffer?.fileURL?.standardizedFileURL.path,
            layout: currentLayout(),
            split: capturedSplit(),
            runConfigs: runConfigs,
            selectedTarget: projectModel.selected?.name
        )
    }

    func restoreWorkspace(_ saved: WorkspaceState) {
        restoringWorkspace = true
        workspaceStore.cancelPending()
        for buffer in buffers {
            SessionService.shared.close(buffer)
            history.forget(bufferID: buffer.id)
        }
        applyLayout(saved.layout)
        runConfigs = saved.runConfigs
        projectModel.restoreSelection(saved.selectedTarget)
        let restored = saved.tabs.compactMap(buffer(from:))
        buffers = restored
        restoreSplit(saved, restored)
        syncSplitFocus()
        selectedURL = activeBuffer?.fileURL
        cursorLine = 1
        cursorColumn = 1
        refreshPreview()
        restoringWorkspace = false
        scheduleWorkspaceSave()
    }

    private func capturedSplit() -> SplitState? {
        guard splitLayout.isSplit else {
            return nil
        }
        return SplitState.from(
            ratio: splitLayout.ratio,
            panes: paneLayout.panes,
            focused: paneLayout.focusedID,
            pathOf: { buffer($0)?.fileURL?.standardizedFileURL.path }
        )
    }

    private func restoreSplit(_ saved: WorkspaceState, _ restored: [BufferDocument]) {
        splitLayout = SplitLayout.restore(saved.split)
        guard let split = saved.split, splitLayout.isSplit else {
            paneLayout.reset(tabs: restored.map(\.id), active: focusedID(saved.focusedPath, in: restored))
            return
        }
        let ids = Dictionary(uniqueKeysWithValues: restored.compactMap { buffer in
            buffer.fileURL.map { ($0.standardizedFileURL.path, buffer.id) }
        })
        paneLayout.restorePanes(split.tabs(ids: ids, leftover: restored.map(\.id)), focused: split.focused)
        if let focused = focusedID(saved.focusedPath, in: restored) {
            paneLayout.select(focused)
        }
    }

    private func tabState(of buffer: BufferDocument) -> TabState? {
        guard let path = buffer.fileURL?.standardizedFileURL.path else {
            return nil
        }
        return TabState(
            path: path,
            caretByte: buffer.caretByte,
            scrollLine: buffer.scrollLine,
            folds: buffer.foldStarts
        )
    }

    private func buffer(from tab: TabState) -> BufferDocument? {
        let url = URL(fileURLWithPath: tab.path).standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
            return nil
        }
        let buffer = BufferDocument(url: url)
        let clamped = tab.clamped(toUtf8Count: buffer.text.utf8.count)
        buffer.caretByte = clamped.caretByte
        buffer.scrollLine = clamped.scrollLine
        buffer.foldStarts = clamped.folds
        buffer.isReadOnly = CatalogPath.isCatalog(url) || BufferLanguage.isReadOnly(url)
        return buffer
    }

    private func focusedID(_ path: String?, in restored: [BufferDocument]) -> UUID? {
        guard let path else {
            return nil
        }
        let standard = URL(fileURLWithPath: path).standardizedFileURL.path
        return restored.first { $0.fileURL?.standardizedFileURL.path == standard }?.id
    }
}
