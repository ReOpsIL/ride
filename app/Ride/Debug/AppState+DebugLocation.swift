import AppKit

extension AppState {
    func debugChanged() {
        debugPanelChanged()
        syncMenu()
        refreshBreakpointGutters()
    }

    func showDebugLocation(path: String?, line: UInt32) {
        guard let path, line > 0 else {
            HighlightApply.clearMarkedLine()
            return
        }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            HighlightApply.clearMarkedLine()
            return
        }
        openFile(url, at: .line(Int(line), mark: true), readOnly: !WorkspaceFS.contains(root: workspaceRoot, file: url))
    }
}
