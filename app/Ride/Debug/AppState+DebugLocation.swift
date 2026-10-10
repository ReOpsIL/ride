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
        let incoming = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: incoming.path) else {
            HighlightApply.clearMarkedLine()
            return
        }
        let url = workspaceRoot.map { WorkspaceFS.spelled(inside: $0, file: incoming) } ?? incoming
        openFile(url, at: .line(Int(line), mark: true), readOnly: !WorkspaceFS.contains(root: workspaceRoot, file: url))
    }
}
