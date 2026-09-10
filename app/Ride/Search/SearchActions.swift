import AppKit

extension AppState {
    func toggleQuickOpen() {
        showFind = false
        showQuickOpen.toggle()
        if showQuickOpen {
            quickQuery = ""
            quickFiles = []
            refreshQuickOpen()
        }
    }

    func refreshQuickOpen() {
        guard let root = workspaceRoot else {
            quickHits = []
            quickSelection = nil
            return
        }
        if quickFiles.isEmpty {
            quickFiles = FileIndex.list(root: root, showHidden: prefs.showHidden)
        }
        quickHits = FileIndex.matches(query: quickQuery, files: quickFiles, root: root)
        if let selected = quickSelection, quickHits.contains(selected) {
            return
        }
        quickSelection = quickHits.first
    }

    func confirmQuickOpen() {
        let url = quickSelection ?? quickHits.first
        showQuickOpen = false
        if let url {
            openFile(url)
        }
    }

    func selectNextQuick() {
        guard let current = quickSelection, let i = quickHits.firstIndex(of: current) else {
            quickSelection = quickHits.first
            return
        }
        quickSelection = quickHits[(i + 1) % quickHits.count]
    }

    func selectPreviousQuick() {
        guard let current = quickSelection, let i = quickHits.firstIndex(of: current) else {
            quickSelection = quickHits.last
            return
        }
        quickSelection = quickHits[(i + quickHits.count - 1) % quickHits.count]
    }

    func toggleFind(replace: Bool = false) {
        showQuickOpen = false
        if showFind, replace, !showReplaceField {
            showReplaceField = true
            return
        }
        showFind.toggle()
        if showFind {
            showReplaceField = replace
            findOrigin = EditorJump.shared.view?.selectedRange().location ?? 0
        }
    }

    func useSelectionForFind() {
        guard let view = EditorJump.shared.view, view.selectedRange().length > 0 else {
            return
        }
        findQuery = (view.string as NSString).substring(with: view.selectedRange())
        findOrigin = NSMaxRange(view.selectedRange())
    }

    func findNext() {
        find(backwards: false)
    }

    func findPrevious() {
        find(backwards: true)
    }

    func replaceOne() {
        guard let buffer = activeBuffer, !findQuery.isEmpty, let view = EditorJump.shared.view else {
            return
        }
        var range = findRange
        let text = view.string
        if range == nil || !isMatch(range!, in: text) {
            find(backwards: false)
            range = findRange
        }
        guard let range, isMatch(range, in: text) else {
            return
        }
        let replacement = FindMatcher.replacement(replaceQuery, options: findOptions)
        let matched = (text as NSString).substring(with: range)
        let text2 = FindMatcher.expression(findQuery, options: findOptions)?
            .stringByReplacingMatches(in: matched, range: NSRange(location: 0, length: (matched as NSString).length), withTemplate: replacement) ?? replaceQuery
        EditorCommand.apply(EditResult(changes: [TextChange(range: range, text: text2)], selection: NSRange(location: range.location, length: (text2 as NSString).length)), to: view)
        buffer.capture(view)
        findOrigin = range.location + (text2 as NSString).length
        findRange = NSRange(location: range.location, length: (text2 as NSString).length)
        find(backwards: false)
    }

    func replaceAll() {
        guard let buffer = activeBuffer, !findQuery.isEmpty, let view = EditorJump.shared.view else {
            return
        }
        let text = view.string
        let matches = FindMatcher.matches(in: text, query: findQuery, options: findOptions)
        guard !matches.isEmpty, let expression = FindMatcher.expression(findQuery, options: findOptions) else {
            return
        }
        let template = FindMatcher.replacement(replaceQuery, options: findOptions)
        let changes = matches.map { range in
            let matched = (text as NSString).substring(with: range)
            let replaced = expression.stringByReplacingMatches(in: matched, range: NSRange(location: 0, length: (matched as NSString).length), withTemplate: template)
            return TextChange(range: range, text: replaced)
        }
        EditorCommand.apply(EditResult(changes: changes, selection: view.selectedRange()), to: view)
        buffer.capture(view)
        findRange = nil
    }

    private func isMatch(_ range: NSRange, in text: String) -> Bool {
        FindMatcher.matches(in: text, query: findQuery, options: findOptions).contains(range)
    }

    private func find(backwards: Bool) {
        guard let view = EditorJump.shared.view, !findQuery.isEmpty else {
            return
        }
        let origin = backwards ? (findRange?.location ?? findOrigin) : findOrigin
        guard let found = FindMatcher.next(in: view.string, query: findQuery, options: findOptions, from: origin, backwards: backwards) else {
            findRange = nil
            return
        }
        findRange = found
        findOrigin = NSMaxRange(found)
        EditorJump.shared.select(found)
    }
}
