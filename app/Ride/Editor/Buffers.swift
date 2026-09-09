import AppKit

extension AppState {
    func openFile(_ url: URL, readOnly: Bool = false) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
            return
        }
        let standard = url.standardizedFileURL
        selectedURL = standard
        CompletionSession.shared.hide()
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
        CompletionSession.shared.hide()
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
        CompletionSession.shared.hide()
        SessionService.shared.close(buffer)
        buffers.removeAll { $0.id == id }
        if activeID == id {
            activeID = buffers.last?.id
            selectedURL = activeBuffer?.fileURL
        }
    }

    func saveActive() {
        guard let buffer = activeBuffer else {
            return
        }
        if buffer.isReadOnly || buffer.fileURL == nil {
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = buffer.displayName + ".rs"
            guard panel.runModal() == .OK, let url = panel.url else {
                return
            }
            buffer.fileURL = url
            buffer.isReadOnly = false
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
        guard let buffer = activeBuffer, buffer.fileURL != nil, buffer.isDirty, !buffer.isReadOnly else {
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
