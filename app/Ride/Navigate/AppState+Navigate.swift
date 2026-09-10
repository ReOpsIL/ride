import AppKit

extension AppState {
    var currentLocation: NavLocation? {
        guard let id = activeID, let view = EditorJump.shared.view else {
            return nil
        }
        return NavLocation(bufferID: id, utf16: view.selectedRange().location)
    }

    private var lineOf: (Int) -> Int {
        { [weak self] utf16 in self?.activeBuffer.map { ($0.text as NSString).lineNumber(at: utf16) } ?? 0 }
    }

    func recordLocation() {
        guard let location = currentLocation else {
            return
        }
        history.record(location, lines: lineOf)
        syncMenu()
    }

    func noteEdit(_ view: RideTextView) {
        guard let id = activeID else {
            return
        }
        history.noteEdit(NavLocation(bufferID: id, utf16: view.selectedRange().location))
    }

    func goBack() {
        guard let current = currentLocation, let target = history.back(from: current, lines: lineOf) else {
            return
        }
        show(target)
    }

    func goForward() {
        guard let target = history.forward() else {
            return
        }
        show(target)
    }

    func goToLastEdit() {
        guard let target = history.lastEdit else {
            return
        }
        recordLocation()
        show(target)
    }

    private func show(_ target: NavLocation) {
        guard buffers.contains(where: { $0.id == target.bufferID }) else {
            history.forget(bufferID: target.bufferID)
            syncMenu()
            return
        }
        if activeID != target.bufferID {
            switchBuffer(target.bufferID)
        }
        EditorJump.shared.select(NSRange(location: target.utf16, length: 0))
        syncMenu()
    }

    private func switchBuffer(_ id: UUID) {
        CompletionSession.shared.reset()
        activeID = id
        selectedURL = activeBuffer?.fileURL
        refreshPreview()
    }

    func toggleGoToLine() {
        let next = !showGoToLine
        closeOverlays()
        showGoToLine = next
        goToLineQuery = ""
    }

    func confirmGoToLine() {
        let parts = goToLineQuery.split(separator: ":").map { Int($0.trimmingCharacters(in: .whitespaces)) }
        showGoToLine = false
        guard let line = parts.first ?? nil, let view = EditorJump.shared.view else {
            return
        }
        recordLocation()
        let starts = view.lineIndex().starts
        let start = starts[min(max(line, 1), starts.count) - 1]
        let column = (parts.count > 1 ? parts[1] : nil) ?? 1
        let lineEnd = (view.string as NSString).lineRange(for: NSRange(location: start, length: 0))
        let location = min(start + max(column - 1, 0), NSMaxRange(lineEnd))
        EditorJump.shared.select(NSRange(location: location, length: 0))
        view.window?.makeFirstResponder(view)
    }

    func noteOpened(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        if recentFiles.count > 30 {
            recentFiles.removeLast(recentFiles.count - 30)
        }
    }

    func toggleRecentFiles() {
        let next = !showRecentFiles
        closeOverlays()
        showRecentFiles = next
        recentQuery = ""
        recentSelection = recentHits.dropFirst().first ?? recentHits.first
    }

    var recentHits: [URL] {
        let q = recentQuery.lowercased()
        return recentFiles.filter { q.isEmpty || $0.lastPathComponent.lowercased().contains(q) }
    }

    func confirmRecentFile() {
        showRecentFiles = false
        if let url = recentSelection ?? recentHits.first {
            openFile(url)
        }
    }

    func moveRecentSelection(_ delta: Int) {
        let hits = recentHits
        guard !hits.isEmpty else {
            return
        }
        let index = recentSelection.flatMap { hits.firstIndex(of: $0) } ?? 0
        recentSelection = hits[(index + delta + hits.count) % hits.count]
    }
}

extension NSString {
    func lineNumber(at utf16: Int) -> Int {
        var count = 1
        var index = 0
        let limit = min(max(utf16, 0), length)
        while index < limit {
            var end = 0
            getLineStart(nil, end: &end, contentsEnd: nil, for: NSRange(location: index, length: 0))
            if end <= index || end > limit {
                break
            }
            count += 1
            index = end
        }
        return count
    }
}
