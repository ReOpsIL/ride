import AppKit

extension AppState {
    var debugPanel: DebugPanelModel {
        DebugPanelModel.shared
    }

    func observeDebugPanel() {
        DebugFilters.shared.onChange = { [weak self] in
            self?.syncMenu()
        }
        DebugFilters.shared.load()
        debugPanel.onFrame = { [weak self] path, line in
            self?.showDebugLocation(path: path, line: line)
        }
        debugPanel.onWatchesChanged = { [weak self] in
            self?.scheduleWorkspaceSave()
        }
        debugPanel.onVisibilityChange = { [weak self] in
            self?.syncMenu()
        }
    }

    func toggleDebugPanel() {
        debugPanel.visible.toggle()
    }

    func showEvaluateSheet() {
        debugPanel.visible = true
        debugPanel.showEvaluate = true
    }

    func toggleExceptionFilter(id: String) {
        DebugFilters.shared.toggle(id: id)
    }

    func debugPanelChanged() {
        debugPanel.sessionChanged()
        guard debug.isStopped else {
            return
        }
        debugPanel.visible = true
    }
}
