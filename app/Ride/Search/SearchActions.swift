import AppKit

extension AppState {
    func toggleFind(replace: Bool = false) {
        if let host = htmlFind() {
            host.toggleFind(replace: replace)
            return
        }
        overlay = nil
        if showFind, replace, !showReplaceField {
            showReplaceField = true
            return
        }
        showFind.toggle()
        if showFind {
            showReplaceField = replace
            findOrigin = EditorPanes.shared.focusedView?.selectedRange().location ?? 0
        }
    }

    func useSelectionForFind() {
        if let host = htmlFind() {
            host.useSelection()
            return
        }
        guard let view = EditorPanes.shared.focusedView, view.selectedRange().length > 0 else {
            return
        }
        findQuery = (view.string as NSString).substring(with: view.selectedRange())
        findOrigin = NSMaxRange(view.selectedRange())
    }

    func closeFind() {
        showFind = false
        makeFocusedEditorFirstResponder()
    }

    func findNext() {
        if let host = htmlFind() {
            host.find(backwards: false)
            return
        }
        find(backwards: false)
    }

    func findPrevious() {
        if let host = htmlFind() {
            host.find(backwards: true)
            return
        }
        find(backwards: true)
    }

    func replaceOne() {
        guard !findQuery.isEmpty, let view = EditorPanes.shared.focusedView else {
            return
        }
        if findRange.map({ !isMatch($0, in: view.string) }) ?? true {
            find(backwards: false)
        }
        let replacements = FindMatcher.replacements(in: view.string, query: findQuery, template: replaceQuery, options: findOptions)
        guard let range = findRange, let change = replacements.first(where: { $0.range == range }) else {
            return
        }
        let length = (change.text as NSString).length
        EditorCommand.apply(EditResult(changes: [change], selection: NSRange(location: range.location, length: length)), to: view)
        EditorPanes.shared.host(for: view)?.capture()
        findOrigin = range.location + length
        findRange = NSRange(location: range.location, length: length)
        find(backwards: false)
    }

    func replaceAll() {
        guard !findQuery.isEmpty, let view = EditorPanes.shared.focusedView else {
            return
        }
        let changes = FindMatcher.replacements(in: view.string, query: findQuery, template: replaceQuery, options: findOptions)
        guard !changes.isEmpty else {
            return
        }
        EditorCommand.apply(EditResult.mapping(view.selectedRange(), through: changes), to: view)
        EditorPanes.shared.host(for: view)?.capture()
        findRange = nil
    }

    private func htmlFind() -> HtmlFindHost? {
        let window = NSApp.keyWindow
        let responder = window?.firstResponder
        if let host = HtmlFindHost.focused(in: responder) {
            return host
        }
        guard responder == nil || responder === window, let window else {
            return nil
        }
        return HtmlFindHost.host(in: window, pane: paneLayout.focusedID)
    }

    private func isMatch(_ range: NSRange, in text: String) -> Bool {
        FindMatcher.matches(in: text, query: findQuery, options: findOptions).contains(range)
    }

    private func find(backwards: Bool) {
        guard let view = EditorPanes.shared.focusedView, !findQuery.isEmpty else {
            return
        }
        let origin = backwards ? (findRange?.location ?? findOrigin) : findOrigin
        guard let found = FindMatcher.next(in: view.string, query: findQuery, options: findOptions, from: origin, backwards: backwards) else {
            findRange = nil
            return
        }
        findRange = found
        findOrigin = NSMaxRange(found)
        EditorPanes.shared.focused?.select(found, focus: false)
    }
}
