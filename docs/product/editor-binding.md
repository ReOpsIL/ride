# Editor binding: which view belongs to which document

An `EditorHostView` is bound to exactly one `BufferDocument` (`EditorHostView.bind`), and a document is shown by at most one host. The host is the only object allowed to copy text between the two (`bind` view ← document, `capture` document ← view).

Rules for app code:

- Never pair `activeBuffer`/`activeID` with `EditorPanes.shared.focusedView`. `PaneLayout` changes synchronously; SwiftUI builds the matching host later, so between the two the focused host still shows the previous document. Use `EditorPanes.shared.host(bound: buffer)` to reach a document's view, or `AppState.focusedEditor` to get a view and its own document together.
- Text that must land in a document (format result, reload from disk, project replace) goes through `AppState.deliver(_:to:disk:)`; caret moves after opening a file go through `AppState.jump(to:in:)` or `openFile(_:at:)`. Both store the pending value on the `BufferDocument` and apply it when its host exists, so a result never lands in another pane.
- Saving, autosave and close prompts take the buffer they act on (`save(_:)`, `autoSave(_:)`, `confirmClose(_:)`), not the active one.
- `EditorPanes` focus follows `PaneLayout.focusedID`: the focused `PaneColumn` adopts its host on every update, and `makeFocusedEditorFirstResponder` on a pane without a host claims first responder for the host that attaches next.
- Workspace capture (`captureWorkspace`) captures every bound host and runs inside the debounced save, not on every caret move.
- Undo history is per document (`BufferDocument.undoManager`), so it survives tab switches and is not shared between split panes.
- Demo mode (`--demo`) disables workspace persistence; a self-test step that exercises the persistence hook must call `state.captureWorkspace()` itself.
