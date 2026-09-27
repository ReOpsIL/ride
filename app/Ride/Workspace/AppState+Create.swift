import AppKit

extension AppState {
    func newFile() {
        let language = NewFilePrompt.language(for: NewFileKind(projectModel.model?.kind))
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.directoryURL = selectedDirectory
        panel.nameFieldStringValue = NewFilePrompt.untitledName(for: language)
        let picker = SaveLanguagePicker(panel: panel, initial: language)
        guard let url = withExtendedLifetime(picker, { ModalPanels.chooseURL(panel) }) else {
            return
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
        fileCreated(url)
    }

    func fileCreated(_ url: URL) {
        RideEngineClient.shared.engine?.workspaceFileChanged(path: url.path)
        reloadTree()
        openFile(url)
    }

    func newFolder() {
        if let directory = selectedDirectory {
            treeNewFolder(in: directory)
        }
    }

    func openAnything() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Open a file, a Cargo project or a folder"
        guard let url = ModalPanels.chooseURL(panel) else {
            return
        }
        if WorkspaceFS.isDirectory(url) {
            open(url)
            return
        }
        if !WorkspaceFS.contains(root: workspaceRoot, file: url), !open(url.deletingLastPathComponent()) {
            return
        }
        openFile(url)
    }
}
