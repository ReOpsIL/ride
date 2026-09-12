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
            self?.showDebugFrame(path: path, line: line)
        }
        debugPanel.onWatchesChanged = { [weak self] in
            self?.scheduleWorkspaceSave()
        }
    }

    func toggleDebugPanel() {
        debugPanel.visible.toggle()
        syncMenu()
    }

    func showEvaluateSheet() {
        debugPanel.visible = true
        debugPanel.showEvaluate = true
        syncMenu()
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
        syncMenu()
    }

    private func showDebugFrame(path: String, line: UInt32) {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        openFile(url, readOnly: !WorkspaceFS.contains(root: workspaceRoot, file: url))
        DispatchQueue.main.async {
            EditorPanes.shared.focused?.jump(toLine: Int(line))
            if let view = EditorPanes.shared.focusedView {
                HighlightApply.markLine(view, line: Int(line))
            }
        }
    }
}
