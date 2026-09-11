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
        selectedURL = activeBuffer?.fileURL
        if let view = EditorPanes.shared.focusedView {
            let index = view.lineIndex()
            let loc = view.selectedRange().location
            cursorLine = index.line(at: loc)
            cursorColumn = index.column(at: loc)
        }
        refreshPreview()
    }
}
