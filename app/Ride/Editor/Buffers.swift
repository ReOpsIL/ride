import AppKit

extension AppState {
    func openFile(_ url: URL, readOnly: Bool = false) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
            return
        }
        let standard = url.standardizedFileURL
        selectedURL = standard
        CompletionSession.shared.reset()
        noteOpened(standard)
        if activeBuffer?.fileURL != standard {
            recordLocation()
        }
        if let existing = buffers.first(where: { $0.fileURL == standard }) {
            existing.isReadOnly = existing.isReadOnly || readOnly
            activeID = existing.id
            refreshPreview()
            return
        }
        let buffer = BufferDocument(url: standard)
        buffer.isReadOnly = readOnly || CatalogPath.isCatalog(standard)
        buffers.append(buffer)
        activeID = buffer.id
        cursorLine = 1
        cursorColumn = 1
        refreshPreview()
    }

    func newUntitled() {
        untitledSeq += 1
        let buffer = BufferDocument(untitled: untitledSeq)
        buffers.append(buffer)
        activeID = buffer.id
        selectedURL = nil
        cursorLine = 1
        cursorColumn = 1
    }

    func selectBuffer(_ id: UUID) {
        CompletionSession.shared.reset()
        recordLocation()
        activeID = id
        selectedURL = buffers.first { $0.id == id }?.fileURL
        cursorLine = 1
        cursorColumn = 1
        refreshPreview()
    }

    func closeBuffer(_ id: UUID) {
        guard let buffer = buffers.first(where: { $0.id == id }) else {
            return
        }
        if buffer.isDirty, !confirmClose(buffer) {
            return
        }
        CompletionSession.shared.reset()
        SessionService.shared.close(buffer)
        history.forget(bufferID: id)
        buffers.removeAll { $0.id == id }
        if activeID == id {
            activeID = buffers.last?.id
            selectedURL = activeBuffer?.fileURL
        }
    }

    func saveActive() {
        guard let buffer = activeBuffer, confirmOverwrite(buffer) else {
            return
        }
        if buffer.isReadOnly || buffer.fileURL == nil {
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = buffer.displayName + "." + buffer.language.fileExtension
            let picker = SaveLanguagePicker(panel: panel, initial: buffer.language)
            let response = withExtendedLifetime(picker) { panel.runModal() }
            guard response == .OK, let url = panel.url else {
                return
            }
            let previous = buffer.language
            buffer.fileURL = url
            buffer.detectedLanguage = nil
            buffer.isReadOnly = false
            if buffer.language != previous, let view = EditorJump.shared.view {
                SessionService.shared.close(buffer)
                SessionService.shared.attach(document: buffer, view: view)
            }
        }
        try? buffer.save(from: nil)
        objectWillChange.send()
        didSave(buffer)
    }

    func scheduleAutoSave() {
        autoSaveWork?.cancel()
        guard prefs.autoSave else {
            objectWillChange.send()
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.autoSaveActive()
        }
        autoSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
        objectWillChange.send()
    }

    func autoSaveActive() {
        guard let buffer = activeBuffer, buffer.fileURL != nil, buffer.isDirty, !buffer.isReadOnly, !buffer.changedOnDisk else {
            return
        }
        try? buffer.save(from: nil)
        objectWillChange.send()
        didSave(buffer)
    }

    func confirmClose(_ buffer: BufferDocument) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Save changes to \(buffer.displayName)?"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            saveActive()
            return buffer.fileURL != nil && !buffer.isDirty
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }
}
