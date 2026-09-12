import Foundation

extension AppState {
    func saveLayout(_ edit: @escaping (inout Preferences) -> Void) {
        edit(&prefs)
        guard persistLayout else {
            return
        }
        layoutSaveWork?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            PreferencesStore.save(self.prefs)
            self.scheduleWorkspaceSave()
        }
        layoutSaveWork = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    func currentLayout() -> LayoutState {
        LayoutState(
            sidebarWidth: prefs.sidebarWidth,
            outlineWidth: prefs.outlineWidth,
            problemsHeight: prefs.problemsHeight,
            runOutputHeight: prefs.runOutputHeight,
            terminalHeight: prefs.terminalHeight,
            previewWidth: prefs.previewWidth,
            showSidebar: showSidebar,
            showProblems: showProblems,
            showRunOutput: showRunOutput,
            showTerminal: showTerminal,
            showPreview: showPreview,
            outlinePanel: prefs.outlinePanel
        )
    }

    func applyLayout(_ layout: LayoutState) {
        let persist = persistLayout
        persistLayout = false
        prefs.sidebarWidth = layout.sidebarWidth
        prefs.outlineWidth = layout.outlineWidth
        prefs.problemsHeight = layout.problemsHeight
        prefs.runOutputHeight = layout.runOutputHeight
        prefs.terminalHeight = layout.terminalHeight
        prefs.previewWidth = layout.previewWidth
        prefs.outlinePanel = layout.outlinePanel
        prefs = prefs.clamped
        showSidebar = layout.showSidebar
        showProblems = layout.showProblems
        showRunOutput = layout.showRunOutput
        showTerminal = layout.showTerminal
        showPreview = layout.showPreview
        persistLayout = persist
        syncMenu()
    }
}
