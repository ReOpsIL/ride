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
        if paneLayout.focusedID != paneID {
            CompletionSession.shared.reset()
            paneLayout.focus(paneID)
            syncSplitFocus()
            selectedURL = activeBuffer?.fileURL
            if let view = EditorPanes.shared.host(paneID)?.textView {
                let index = view.lineIndex()
                let loc = view.selectedRange().location
                cursorLine = index.line(at: loc)
                cursorColumn = index.column(at: loc)
            }
            refreshPreview()
        }
        makeFocusedEditorFirstResponder()
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
        splitLayout.toggle()
        _ = paneLayout.split()
        syncSplitFocus()
        makeFocusedEditorFirstResponder()
    }

    func closeSplit() {
        if paneLayout.panes.count > 1 {
            paneLayout.closePane(paneLayout.panes[1].id)
        }
        splitLayout.closeRight()
        makeFocusedEditorFirstResponder()
    }

    func openInSplit(_ bufferID: UUID? = nil) {
        let id = bufferID ?? activeID
        guard let id else {
            return
        }
        if !splitLayout.isSplit {
            openSplit()
            paneLayout.move(id, to: paneLayout.focusedID)
            selectedURL = buffer(id)?.fileURL
            makeFocusedEditorFirstResponder()
            return
        }
        guard let other = paneLayout.neighbour(of: paneLayout.focusedID) else {
            return
        }
        paneLayout.move(id, to: other.id)
        selectedURL = buffer(id)?.fileURL
        syncSplitFocus()
        makeFocusedEditorFirstResponder()
    }

    func moveTab(_ bufferID: UUID, to paneID: UUID) {
        guard buffers.contains(where: { $0.id == bufferID }) else {
            return
        }
        paneLayout.move(bufferID, to: paneID)
        selectedURL = buffer(bufferID)?.fileURL
        syncSplitFocus()
        refreshPreview()
        makeFocusedEditorFirstResponder()
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

    func makeFocusedEditorFirstResponder() {
        if let view = EditorPanes.shared.host(paneLayout.focusedID)?.textView {
            if view.window?.firstResponder !== view {
                view.window?.makeFirstResponder(view)
            }
            return
        }
        EditorPanes.shared.focusedView?.window?.makeFirstResponder(nil)
    }
}
