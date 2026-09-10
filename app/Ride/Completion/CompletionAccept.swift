import AppKit

extension CompletionSession {
    private static let callable: Set<ItemKind> = [.fn, .method, .macro]

    func accept() -> Bool {
        guard popup.isVisible, let hit = popup.selectedHit, let list, let view = popup.textView,
              let binding = view.hooks.binding?()
        else {
            return false
        }
        hide()
        let caret = view.selectedRange().location
        let start = min(Self.replaceStart(for: hit, list: list, in: view), caret)
        editSource = .completion
        insert(hit, replacing: NSRange(location: start, length: caret - start), in: view)
        if list.site == .include, hit.itemKind == .header {
            Self.closeInclude(in: view, before: start)
        }
        editSource = .user
        if let path = hit.importPath {
            applyImport(path, document: binding.document, view: view)
        }
        if list.site == .include, hit.itemKind == .mod {
            schedule(document: binding.document, view: view, state: binding.state)
        }
        if Self.callable.contains(hit.itemKind) {
            SignatureHelpController.shared.show(document: binding.document, view: view)
        }
        return true
    }

    private static func replaceStart(for hit: CompletionHit, list: CompletionList, in view: RideTextView) -> Int {
        guard let byte = hit.replaceStartByte else {
            return list.replaceUtf16
        }
        return Utf16.utf16Offset(in: view.string, utf8: Int(byte))
    }

    private func insert(_ hit: CompletionHit, replacing range: NSRange, in view: RideTextView) {
        if let session = SnippetInsert.insert(hit.insertText, snippet: hit.snippet, replacing: range, in: view) {
            snippet = session
        }
    }

    private static func closeInclude(in view: RideTextView, before start: Int) {
        let ns = view.string as NSString
        let lineStart = ns.lineRange(for: NSRange(location: start, length: 0)).location
        let head = ns.substring(with: NSRange(location: lineStart, length: start - lineStart))
        guard let opener = head.last(where: { $0 == "<" || $0 == "\"" }) else {
            return
        }
        let closer = opener == "<" ? ">" : "\""
        let caret = view.selectedRange().location
        if caret < ns.length, ns.substring(with: NSRange(location: caret, length: 1)) == closer {
            view.setSelectedRange(NSRange(location: caret + 1, length: 0))
        } else {
            view.insertText(closer, replacementRange: NSRange(location: caret, length: 0))
        }
    }

    private func applyImport(_ path: String, document: BufferDocument, view: RideTextView) {
        SessionService.shared.importEdit(document: document, importPath: path) { [weak self, weak view] edit in
            guard let self, let view, let edit else {
                return
            }
            let text = view.string
            let range = Utf16.nsRange(in: text, startByte: edit.startByte, endByte: edit.endByte)
            guard NSMaxRange(range) <= (text as NSString).length else {
                return
            }
            let caret = view.selectedRange()
            self.editSource = .importLine
            view.replaceText(in: range, with: edit.text)
            self.editSource = .user
            let delta = edit.text.utf16.count - range.length
            let location = caret.location >= NSMaxRange(range) ? caret.location + delta : caret.location
            view.setSelectedRange(NSRange(location: location, length: caret.length))
        }
    }
}
