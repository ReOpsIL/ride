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

    func toggleFind() {
        showQuickOpen = false
        showFind.toggle()
        if showFind {
            findOrigin = 0
        }
    }

    func findNext() {
        find(direction: 1)
    }

    func findPrevious() {
        find(direction: -1)
    }

    func replaceOne() {
        guard let buffer = activeBuffer else {
            return
        }
        let ns = buffer.text as NSString
        let q = findQuery
        guard !q.isEmpty else {
            return
        }
        var range = findRange
        if range == nil || ns.substring(with: clamped(range!, in: ns)).caseInsensitiveCompare(q) != .orderedSame {
            find(direction: 1)
            range = findRange
        }
        guard let range, range.length > 0, range.location + range.length <= ns.length else {
            return
        }
        buffer.text = ns.replacingCharacters(in: range, with: replaceQuery)
        buffer.isDirty = true
        findOrigin = range.location + (replaceQuery as NSString).length
        let replacedRange = NSRange(location: range.location, length: (replaceQuery as NSString).length)
        findRange = replacedRange
        EditorJump.shared.replaceText(buffer.text)
        if let view = EditorJump.shared.view {
            SessionService.shared.resync(document: buffer, view: view)
        }
        EditorJump.shared.select(replacedRange)
        if prefs.autoSave {
            scheduleAutoSave()
        }
    }

    func replaceAll() {
        guard let buffer = activeBuffer, !findQuery.isEmpty else {
            return
        }
        let replaced = (buffer.text as NSString).replacingOccurrences(
            of: findQuery,
            with: replaceQuery,
            options: .caseInsensitive,
            range: NSRange(location: 0, length: (buffer.text as NSString).length)
        )
        if replaced != buffer.text {
            buffer.text = replaced
            buffer.isDirty = true
            EditorJump.shared.replaceText(replaced)
            if let view = EditorJump.shared.view {
                SessionService.shared.resync(document: buffer, view: view)
            }
            if prefs.autoSave {
                scheduleAutoSave()
            }
        }
    }

    private func find(direction: Int) {
        guard let buffer = activeBuffer else {
            return
        }
        let ns = buffer.text as NSString
        let q = findQuery
        guard !q.isEmpty, ns.length > 0 else {
            return
        }
        if direction >= 0 {
            let start = min(max(findOrigin, 0), ns.length)
            var found = ns.range(of: q, options: .caseInsensitive, range: NSRange(location: start, length: ns.length - start))
            if found.location == NSNotFound {
                found = ns.range(of: q, options: .caseInsensitive, range: NSRange(location: 0, length: start))
            }
            applyFound(found, nsLength: ns.length)
        } else {
            let end = min(max(findOrigin, 0), ns.length)
            var found = ns.range(
                of: q,
                options: [.caseInsensitive, .backwards],
                range: NSRange(location: 0, length: end)
            )
            if found.location == NSNotFound {
                found = ns.range(
                    of: q,
                    options: [.caseInsensitive, .backwards],
                    range: NSRange(location: 0, length: ns.length)
                )
            }
            applyFound(found, nsLength: ns.length)
        }
    }

    private func applyFound(_ found: NSRange, nsLength: Int) {
        if found.location == NSNotFound {
            return
        }
        findRange = found
        findOrigin = min(found.location + found.length, nsLength)
        EditorJump.shared.select(found)
    }

    private func clamped(_ range: NSRange, in ns: NSString) -> NSRange {
        let loc = min(max(range.location, 0), ns.length)
        let len = min(max(range.length, 0), ns.length - loc)
        return NSRange(location: loc, length: len)
    }
}
