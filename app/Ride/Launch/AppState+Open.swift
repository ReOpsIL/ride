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
        guard WorkspaceFS.isFile(url), enterWorkspace(WorkspaceRootFinder.root(for: url)) else {
            return
        }
        if let target = request.jump {
            openFile(url, at: target)
        } else {
            openFile(url)
        }
        makeFocusedEditorFirstResponder()
    }

    @discardableResult
    private func enterWorkspace(_ root: URL) -> Bool {
        NSApp.windows.first { $0.isVisible && !($0 is NSPanel) }?.makeKeyAndOrderFront(nil)
        return workspaceRoot?.standardizedFileURL == root || open(root)
    }
}
