import AppKit

extension AppState {
    func saveAll() {
        for buffer in buffers where buffer.isDirty && buffer.fileURL != nil && !buffer.isReadOnly {
            persist(buffer, allowFormat: false)
        }
        objectWillChange.send()
    }

    func saveAs() {
        guard let buffer = activeBuffer, let url = chooseSaveURL(for: buffer) else {
            return
        }
        rebind(buffer, to: url)
        persist(buffer)
        objectWillChange.send()
    }

    func revertToSaved() {
        guard let buffer = activeBuffer, buffer.fileURL != nil else {
            return
        }
        if buffer.isDirty, !Confirm.ask("Revert \(buffer.displayName) to the saved version?", message: "Your unsaved changes will be lost.", ok: "Revert") {
            return
        }
        reloadFromDisk(buffer)
    }

    func reloadFromDisk(_ buffer: BufferDocument) {
        guard let loaded = buffer.readDisk() else {
            return
        }
        replaceText(of: buffer, with: loaded.text)
        buffer.markLoaded(loaded)
        objectWillChange.send()
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
        paneLayout = PaneLayout()
        splitLayout = SplitLayout()
        return true
    }

    func closeOthers(keeping id: UUID? = nil) {
        guard let keep = id ?? activeID else {
            return
        }
        let pane = paneLayout.pane(showing: keep)
        for buffer in buffers where buffer.id != keep && pane?.tabs.contains(buffer.id) != false {
            closeBuffer(buffer.id)
            if buffers.contains(where: { $0.id == buffer.id }) {
                break
            }
        }
        if activeID != keep {
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
        switch Confirm.overwrite(buffer.displayName) {
        case .overwrite:
            buffer.changedOnDisk = false
            return true
        case .reload:
            reloadFromDisk(buffer)
            return false
        case .cancel:
            return false
        }
    }
}
