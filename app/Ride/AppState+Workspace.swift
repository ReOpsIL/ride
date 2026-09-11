import AppKit

extension AppState {
    func watchWorkspaceQuit() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flushWorkspace()
        }
    }

    var canPersistWorkspace: Bool {
        persistLayout && !DemoLaunch.isDemo && workspaceRoot != nil
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

    func restoreOpenedWorkspace() {
        guard !DemoLaunch.isDemo, let root = workspaceRoot, let saved = workspaceStore.load(root: root) else {
            return
        }
        restoreWorkspace(saved)
    }

    func captureWorkspace() -> WorkspaceState {
        if !restoringWorkspace, let view = EditorJump.shared.view, let buffer = activeBuffer, buffer.id == activeID {
            buffer.capture(view)
        }
        return WorkspaceState(
            tabs: buffers.compactMap(tabState(of:)),
            focusedPath: activeBuffer?.fileURL?.standardizedFileURL.path,
            layout: currentLayout(),
            split: nil
        )
    }

    func restoreWorkspace(_ saved: WorkspaceState) {
        restoringWorkspace = true
        for buffer in buffers {
            SessionService.shared.close(buffer)
            history.forget(bufferID: buffer.id)
        }
        applyLayout(saved.layout)
        let restored = saved.tabs.compactMap(buffer(from:))
        buffers = restored
        activeID = focusedID(saved.focusedPath, in: restored) ?? restored.last?.id
        selectedURL = activeBuffer?.fileURL
        cursorLine = 1
        cursorColumn = 1
        refreshPreview()
        restoringWorkspace = false
    }

    private func currentLayout() -> LayoutState {
        LayoutState(
            sidebarWidth: prefs.sidebarWidth,
            outlineWidth: prefs.outlineWidth,
            problemsHeight: prefs.problemsHeight,
            previewWidth: prefs.previewWidth,
            showSidebar: showSidebar,
            showProblems: showProblems,
            showPreview: showPreview,
            outlinePanel: prefs.outlinePanel
        )
    }

    private func applyLayout(_ layout: LayoutState) {
        let persist = persistLayout
        persistLayout = false
        prefs.sidebarWidth = layout.sidebarWidth
        prefs.outlineWidth = layout.outlineWidth
        prefs.problemsHeight = layout.problemsHeight
        prefs.previewWidth = layout.previewWidth
        prefs.outlinePanel = layout.outlinePanel
        prefs = prefs.clamped
        showSidebar = layout.showSidebar
        showProblems = layout.showProblems
        showPreview = layout.showPreview
        persistLayout = persist
        syncMenu()
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
