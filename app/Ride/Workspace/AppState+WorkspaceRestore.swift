import AppKit

extension AppState {
    func captureWorkspace() -> WorkspaceState {
        if !restoringWorkspace {
            EditorPanes.shared.all.forEach { $0.capture() }
        }
        return WorkspaceState(
            tabs: buffers.compactMap(tabState(of:)),
            focusedPath: activeBuffer?.fileURL?.standardizedFileURL.path,
            layout: currentLayout(),
            split: capturedSplit(),
            runConfigs: runConfigs,
            selectedTarget: projectModel.selected?.name,
            profile: projectModel.profile.isEmpty ? nil : projectModel.profile,
            breakpoints: DebugController.shared.breakpoints,
            watches: DebugPanelModel.shared.expressions
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
        DebugController.shared.breakpoints = saved.breakpoints
        DebugPanelModel.shared.restore(watches: saved.watches)
        projectModel.restoreProfile(saved.profile)
        projectModel.restoreSelection(saved.selectedTarget)
        let restored = saved.tabs.compactMap(buffer(from:))
        buffers = restored
        restoreSplit(saved, restored)
        syncSplitFocus()
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
        let ids = Dictionary(restored.compactMap { buffer in
            buffer.fileURL.map { ($0.standardizedFileURL.path, buffer.id) }
        }, uniquingKeysWith: { first, _ in first })
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
        guard WorkspaceFS.isFile(url) else {
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
