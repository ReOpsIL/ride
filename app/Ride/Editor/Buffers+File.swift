import AppKit

extension AppState {
    func newFile() {
        let directory = selectedURL.map { WorkspaceFS.parentDir(for: $0, isDirectory: isDirectory($0)) } ?? workspaceRoot
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.directoryURL = directory
        panel.nameFieldStringValue = "untitled.rs"
        let picker = SaveLanguagePicker(panel: panel, initial: .rust)
        let response = withExtendedLifetime(picker) { panel.runModal() }
        guard response == .OK, let url = panel.url else {
            return
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
        RideEngineClient.shared.engine?.workspaceFileChanged(path: url.path)
        reloadTree()
        openFile(url)
    }

    func newFolder() {
        let directory = selectedURL.map { WorkspaceFS.parentDir(for: $0, isDirectory: isDirectory($0)) } ?? workspaceRoot
        guard let directory else {
            return
        }
        TreeActions.newFolder(in: directory)
        reloadTree()
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    func openAnything() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Open a file, a Cargo project or a folder"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        if isDirectory(url) {
            open(url)
            return
        }
        if !WorkspaceFS.contains(root: workspaceRoot, file: url) {
            open(url.deletingLastPathComponent())
        }
        openFile(url)
    }

    func closeWorkspace() {
        flushWorkspace()
        guard closeAll() else {
            return
        }
        workspaceRoot = nil
        rootNodes = []
        selectedURL = nil
        expanded = []
        quickFiles = []
        git.clear()
    }

    func saveAll() {
        for buffer in buffers where buffer.isDirty && buffer.fileURL != nil && !buffer.isReadOnly {
            if buffer.id == activeID, let view = EditorJump.shared.view {
                buffer.capture(view)
            }
            try? buffer.save(from: nil)
            didSave(buffer, allowFormat: false)
        }
        objectWillChange.send()
    }

    func saveAs() {
        guard let buffer = activeBuffer else {
            return
        }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.directoryURL = buffer.fileURL?.deletingLastPathComponent() ?? workspaceRoot
        panel.nameFieldStringValue = buffer.fileURL?.lastPathComponent ?? buffer.displayName + "." + buffer.language.fileExtension
        let picker = SaveLanguagePicker(panel: panel, initial: buffer.language)
        let response = withExtendedLifetime(picker) { panel.runModal() }
        guard response == .OK, let url = panel.url else {
            return
        }
        let previous = buffer.language
        buffer.fileURL = url.standardizedFileURL
        buffer.detectedLanguage = nil
        buffer.isReadOnly = false
        if let view = EditorJump.shared.view {
            buffer.capture(view)
            if buffer.language != previous {
                SessionService.shared.close(buffer)
                SessionService.shared.attach(document: buffer, view: view)
            }
        }
        try? buffer.save(from: nil)
        selectedURL = buffer.fileURL
        objectWillChange.send()
        didSave(buffer)
    }

    func revertToSaved() {
        guard let buffer = activeBuffer, buffer.fileURL != nil else {
            return
        }
        if buffer.isDirty {
            let alert = NSAlert()
            alert.messageText = "Revert \(buffer.displayName) to the saved version?"
            alert.informativeText = "Your unsaved changes will be lost."
            alert.addButton(withTitle: "Revert")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else {
                return
            }
        }
        reloadFromDisk(buffer)
    }

    func reloadFromDisk(_ buffer: BufferDocument) {
        guard buffer.reload() else {
            return
        }
        buffer.changedOnDisk = false
        if buffer.id == activeID {
            applyText = buffer.text
            applyThenSave = false
            objectWillChange.send()
        }
    }

    @discardableResult
    func closeAll() -> Bool {
        for buffer in buffers {
            if buffer.isDirty {
                activeID = buffer.id
                if !confirmClose(buffer) {
                    return false
                }
            }
        }
        CompletionSession.shared.reset()
        for buffer in buffers {
            SessionService.shared.close(buffer)
            history.forget(bufferID: buffer.id)
        }
        buffers = []
        activeID = nil
        return true
    }

    func closeOthers(keeping id: UUID? = nil) {
        let keep = id ?? activeID
        for buffer in buffers where buffer.id != keep {
            closeBuffer(buffer.id)
        }
        if let keep, activeID != keep {
            selectBuffer(keep)
        }
    }

    func diskChanged(paths: [String]) {
        for buffer in buffers {
            guard let url = buffer.fileURL, paths.contains(url.path) else {
                continue
            }
            if buffer.isDirty {
                buffer.changedOnDisk = buffer.differsFromDisk()
            } else if buffer.differsFromDisk() {
                reloadFromDisk(buffer)
            }
        }
    }

    func confirmOverwrite(_ buffer: BufferDocument) -> Bool {
        guard buffer.changedOnDisk else {
            return true
        }
        let alert = NSAlert()
        alert.messageText = "\(buffer.displayName) changed on disk"
        alert.informativeText = "Overwrite the file with your version, or reload it and lose your changes?"
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            buffer.changedOnDisk = false
            return true
        case .alertSecondButtonReturn:
            reloadFromDisk(buffer)
            return false
        default:
            return false
        }
    }
}
