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

Undo grouping:

- `BufferDocument.undoManager` is built by `UndoStep.manager()` with `groupsByEvent = false`. AppKit's per-event grouping closes a top-level group from `-[NSApplication _handleEvent:]` only, so edits applied from timers, engine callbacks or the self-test (no NSEvent between them) all land in one group and a single ⌘Z reverts every one of them. That is the cause of the 2026-09-20 self-test undo flake.
- With event grouping off, the editor owns the group: `EditorPane.Coordinator.textView(_:shouldChangeTextIn:)` calls `UndoStep.open` and `textDidChange` calls `UndoStep.close`, so one text change is one undo step and the grouping level is 0 whenever `undo()` can be called (with `groupsByEvent = false`, `undo()` raises on any open group). NSTextView coalesces a typing run into the operation registered by its first keystroke; the groups opened by the following keystrokes are empty and Foundation drops them.
- Every programmatic edit goes through `RideTextView.applyChanges` (`EditorCommand.apply`, `RideTextView.applyTyping`, `EditorHostView.replaceText`), which breaks undo coalescing and runs the whole batch inside `UndoStep.perform`: one undo step for the batch, regardless of how many `TextChange`s it holds. `UndoStep` suppresses the per-change close while a batch is open, and `RideTextView.breakUndoCoalescing` closes the open group so a coalescing break is also a step boundary.
- `UndoStep` never touches a group while the manager is undoing or redoing; Foundation opens and closes that one itself.
