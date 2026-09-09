import AppKit

enum TreeActions {
    static func prompt(title: String, defaultName: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: defaultName)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    static func newFile(in directory: URL) {
        guard let name = prompt(title: "New File", defaultName: "untitled.rs") else {
            return
        }
        let url = directory.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data())
        RideEngineClient.shared.engine?.workspaceFileChanged(path: url.path)
    }

    static func newFolder(in directory: URL) {
        guard let name = prompt(title: "New Folder", defaultName: "untitled") else {
            return
        }
        try? FileManager.default.createDirectory(
            at: directory.appendingPathComponent(name),
            withIntermediateDirectories: false
        )
    }

    static func rename(_ url: URL) {
        guard let name = prompt(title: "Rename", defaultName: url.lastPathComponent) else {
            return
        }
        let dest = url.deletingLastPathComponent().appendingPathComponent(name)
        try? FileManager.default.moveItem(at: url, to: dest)
        RideEngineClient.shared.engine?.workspaceFileChanged(path: url.path)
        RideEngineClient.shared.engine?.workspaceFileChanged(path: dest.path)
    }

    static func trash(_ url: URL) {
        NSWorkspace.shared.recycle([url], completionHandler: nil)
        RideEngineClient.shared.engine?.workspaceFileChanged(path: url.path)
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
