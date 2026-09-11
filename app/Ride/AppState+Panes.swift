import AppKit

extension AppState {
    var activeID: UUID? {
        get { paneLayout.activeID }
        set { paneLayout.activeID = newValue }
    }

    func buffer(_ id: UUID?) -> BufferDocument? {
        buffers.first { $0.id == id }
    }

    func paneFocused(_ paneID: UUID) {
        guard paneLayout.focusedID != paneID else {
            return
        }
        CompletionSession.shared.reset()
        paneLayout.focus(paneID)
        syncSplitFocus()
        selectedURL = activeBuffer?.fileURL
        if let view = EditorPanes.shared.focusedView {
            let index = view.lineIndex()
            let loc = view.selectedRange().location
            cursorLine = index.line(at: loc)
            cursorColumn = index.column(at: loc)
        }
        refreshPreview()
    }

    func toggleSplit() {
        if splitLayout.isSplit {
            closeSplit()
        } else {
            openSplit()
        }
    }

    func openSplit() {
        guard !splitLayout.isSplit else {
            return
        }
        let current = paneLayout.activeID
        splitLayout.toggle()
        let paneID = paneLayout.split()
        if let current {
            paneLayout.open(current, in: paneID)
        }
        syncSplitFocus()
    }

    func closeSplit() {
        if paneLayout.panes.count > 1 {
            paneLayout.closePane(paneLayout.panes[1].id)
        }
        splitLayout.closeRight()
    }

    func openInSplit(_ bufferID: UUID? = nil) {
        let id = bufferID ?? activeID
        guard let id else {
            return
        }
        if !splitLayout.isSplit {
            let current = paneLayout.activeID
            openSplit()
            if id != current {
                paneLayout.open(id, in: paneLayout.focusedID)
            }
            selectedURL = buffer(id)?.fileURL
            return
        }
        guard let other = paneLayout.neighbour(of: paneLayout.focusedID) else {
            return
        }
        paneLayout.open(id, in: other.id)
        paneLayout.focus(other.id)
        selectedURL = buffer(id)?.fileURL
        syncSplitFocus()
    }

    func moveTab(_ bufferID: UUID, to paneID: UUID) {
        guard buffers.contains(where: { $0.id == bufferID }) else {
            return
        }
        paneLayout.move(bufferID, to: paneID)
        selectedURL = buffer(bufferID)?.fileURL
        syncSplitFocus()
        refreshPreview()
    }

    func setSplitRatio(_ ratio: Double) {
        var next = splitLayout
        next.setRatio(ratio)
        if next != splitLayout {
            splitLayout = next
        }
    }

    func syncSplitFocus() {
        let left = paneLayout.panes.first?.id
        let side: SplitSide = left == paneLayout.focusedID ? .left : .right
        var next = splitLayout
        next.focus(side)
        if next != splitLayout {
            splitLayout = next
        }
    }
}
