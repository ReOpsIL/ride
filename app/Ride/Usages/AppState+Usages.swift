import AppKit

extension AppState {
    func findUsages() {
        guard let (view, document) = focusedEditor, let id = document.sessionId else {
            return
        }
        let byte = UInt32(Utf16.utf8Offset(in: view.string, utf16: view.selectedRange().location))
        showUsages = true
        usages.query(sessionId: id, byte: byte)
    }

    func toggleUsages() {
        showUsages.toggle()
    }

    func openUsage(path: String, byte: UInt32) {
        let url = usageURL(path)
        openFile(url, at: .byte(byte), readOnly: !WorkspaceFS.contains(root: workspaceRoot, file: url))
    }

    func indexOpenBuffers() {
        UsageIndexer.index(buffers)
    }

    func usageURL(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }
        if let root = workspaceRoot {
            return root.appendingPathComponent(path).standardizedFileURL
        }
        return URL(fileURLWithPath: path).standardizedFileURL
    }
}
