import Foundation

extension AppState {
    func toggleQuickOpen() {
        guard toggleOverlay(.quickOpen) else {
            return
        }
        quickQuery = ""
        quickFiles = []
        refreshQuickOpen()
    }

    func refreshQuickOpen() {
        guard let root = workspaceRoot else {
            quickHits = []
            quickSelection = nil
            return
        }
        if quickFiles.isEmpty {
            loadQuickFiles(root)
        }
        updateQuickHits(root)
    }

    private func loadQuickFiles(_ root: URL) {
        guard QuickFilesLoad.root != root else {
            return
        }
        QuickFilesLoad.root = root
        let hidden = prefs.showHidden
        DispatchQueue.global(qos: .userInitiated).async {
            let files = FileIndex.list(root: root, showHidden: hidden)
            DispatchQueue.main.async { [weak self] in
                QuickFilesLoad.root = nil
                guard let self, self.workspaceRoot == root else {
                    return
                }
                self.quickFiles = files
                self.updateQuickHits(root)
            }
        }
    }

    private func updateQuickHits(_ root: URL) {
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
}

private enum QuickFilesLoad {
    static var root: URL?
}
