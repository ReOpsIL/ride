import AppKit

extension OpenRequest {
    var jump: PendingJump? {
        guard let line else {
            return nil
        }
        guard let column else {
            return .line(line, mark: false)
        }
        return .position(line: line, column: column)
    }
}

extension AppState {
    func openPath(_ url: URL) {
        openRequest(OpenRequest(path: url.path, line: nil, column: nil))
    }

    func openRequest(_ request: OpenRequest) {
        let url = URL(fileURLWithPath: request.path).standardizedFileURL
        if WorkspaceFS.isDirectory(url) {
            enterWorkspace(url)
            return
        }
        guard WorkspaceFS.isFile(url) else {
            return
        }
        enterWorkspace(WorkspaceRootFinder.root(for: url))
        if let target = request.jump {
            openFile(url, at: target)
        } else {
            openFile(url)
        }
        makeFocusedEditorFirstResponder()
    }

    private func enterWorkspace(_ root: URL) {
        if workspaceRoot?.standardizedFileURL != root {
            open(root)
        }
        NSApp.windows.first { $0.isVisible && !($0 is NSPanel) }?.makeKeyAndOrderFront(nil)
    }
}
