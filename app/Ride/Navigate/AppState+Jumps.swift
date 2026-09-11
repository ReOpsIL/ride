import AppKit

extension AppState {
    func nextProblem(_ delta: Int) {
        let all = CheckService.shared.diagnostics
        guard !all.isEmpty else {
            return
        }
        let path = activeBuffer?.fileURL?.path ?? ""
        let byte = EditorPanes.shared.focusedView.map { UInt32(Utf16.utf8Offset(in: $0.string, utf16: $0.selectedRange().location)) } ?? 0
        let index: Int
        if delta > 0 {
            index = all.firstIndex { ($0.path, $0.byteStart) > (path, byte) } ?? 0
        } else {
            index = all.lastIndex { ($0.path, $0.byteStart) < (path, byte) } ?? all.count - 1
        }
        recordLocation()
        openDiagnostic(all[index])
    }

    func nextMethod(_ delta: Int) {
        guard let buffer = activeBuffer, let view = EditorPanes.shared.focusedView else {
            return
        }
        let starts = buffer.outline.map(\.startByte).sorted()
        guard !starts.isEmpty else {
            return
        }
        let byte = UInt32(Utf16.utf8Offset(in: view.string, utf16: view.selectedRange().location))
        let target: UInt32?
        if delta > 0 {
            target = starts.first { $0 > byte }
        } else {
            target = starts.last { $0 < byte }
        }
        guard let target else {
            return
        }
        jumpTo(byte: target)
    }

    func switchHeaderSource() {
        guard let url = activeBuffer?.fileURL, let sibling = SiblingSource.existing(for: url) else {
            return
        }
        recordLocation()
        openFile(sibling)
    }

    func showQuickDocumentation() {
        guard let view = EditorPanes.shared.focusedView else {
            return
        }
        let caret = view.selectedRange().location
        guard let range = IdentifierRange.at(view.string as NSString, index: caret) else {
            return
        }
        HoverController.shared.present(view: view, range: range)
    }

    func showSignatureHelp() {
        guard let view = EditorPanes.shared.focusedView, let buffer = activeBuffer else {
            return
        }
        SignatureHelpController.shared.show(document: buffer, view: view)
    }

    func copyReference() {
        guard let buffer = activeBuffer else {
            return
        }
        let path = buffer.fileURL.map { url in
            workspaceRoot.map { WorkspaceFS.relativePath(root: $0, file: url) } ?? url.path
        } ?? buffer.displayName
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(path):\(cursorLine)", forType: .string)
        showNotice("Copied \(path):\(cursorLine)", seconds: 2)
    }
}
