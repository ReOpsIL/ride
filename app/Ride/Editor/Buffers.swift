import AppKit

extension AppState {
    func openFile(_ url: URL, readOnly: Bool = false) {
        guard WorkspaceFS.isFile(url) else {
            return
        }
        let standard = url.standardizedFileURL
        selectedURL = standard
        CompletionSession.shared.reset()
        noteOpened(standard)
        if activeBuffer?.fileURL != standard {
            recordLocation()
        }
        if let existing = buffer(for: standard) {
            existing.isReadOnly = existing.isReadOnly || readOnly || BufferLanguage.isReadOnly(standard)
            paneLayout.select(existing.id)
            syncSplitFocus()
            refreshPreview()
            return
        }
        let buffer = BufferDocument(url: standard)
        buffer.isReadOnly = readOnly || CatalogPath.isCatalog(standard) || BufferLanguage.isReadOnly(standard)
        buffers.append(buffer)
        activeID = buffer.id
        cursorLine = 1
        cursorColumn = 1
        refreshPreview()
    }

    func buffer(for url: URL) -> BufferDocument? {
        let standard = url.standardizedFileURL
        return buffers.first { $0.fileURL == standard }
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

    func selectBuffer(_ id: UUID, in paneID: UUID? = nil) {
        CompletionSession.shared.reset()
        recordLocation()
        if let paneID {
            paneLayout.focus(paneID)
            paneLayout.open(id, in: paneID)
        } else {
            paneLayout.select(id)
        }
        syncSplitFocus()
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
        selectedURL = activeBuffer?.fileURL
    }

    func saveActive() {
        if let buffer = activeBuffer {
            save(buffer)
        }
    }

    func save(_ buffer: BufferDocument) {
        guard confirmOverwrite(buffer) else {
            return
        }
        if buffer.isReadOnly || buffer.fileURL == nil {
            guard let url = chooseSaveURL(for: buffer) else {
                return
            }
            rebind(buffer, to: url)
        } else {
            EditorPanes.shared.host(bound: buffer)?.capture()
        }
        try? buffer.save(from: nil)
        objectWillChange.send()
        didSave(buffer)
    }

    func scheduleAutoSave(_ buffer: BufferDocument) {
        buffer.autoSaveWork?.cancel()
        guard prefs.autoSave else {
            objectWillChange.send()
            return
        }
        let work = DispatchWorkItem { [weak self, weak buffer] in
            if let buffer {
                self?.autoSave(buffer)
            }
        }
        buffer.autoSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
        objectWillChange.send()
    }

    func autoSave(_ buffer: BufferDocument) {
        guard buffer.fileURL != nil, buffer.isDirty, !buffer.isReadOnly, !buffer.changedOnDisk else {
            return
        }
        EditorPanes.shared.host(bound: buffer)?.capture()
        try? buffer.save(from: nil)
        objectWillChange.send()
        didSave(buffer)
    }

    func confirmClose(_ buffer: BufferDocument) -> Bool {
        guard !DemoLaunch.isDemo else {
            return true
        }
        let alert = NSAlert()
        alert.messageText = "Save changes to \(buffer.displayName)?"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            save(buffer)
            return buffer.fileURL != nil && !buffer.isDirty
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }
}
