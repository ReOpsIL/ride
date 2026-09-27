import AppKit

enum TreeActions {
    static func trash(_ url: URL, completion: @escaping (Error?) -> Void) {
        guard Confirm.ask("Delete \(url.lastPathComponent)?", message: "The item will be moved to the Trash.", ok: "Delete") else {
            return
        }
        NSWorkspace.shared.recycle([url]) { _, error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func copyPath(_ url: URL, root: URL?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pathText(url, root: root), forType: .string)
    }

    static func pathText(_ url: URL, root: URL?) -> String {
        root.map { WorkspaceFS.relativePath(root: $0, file: url) } ?? url.path
    }
}
