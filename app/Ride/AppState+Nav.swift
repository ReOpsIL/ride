import Foundation

extension AppState {
    func nextQueryId() -> UInt64 {
        queryCounter += 1
        latestQueryId = queryCounter
        return latestQueryId
    }

    func jumpTo(byte: UInt32) {
        recordLocation()
        EditorPanes.shared.focused?.jump(byte: byte)
    }

    func toggleSymbolPicker() {
        if toggleOverlay(.symbolInProject) {
            symbolPicker.reset()
        }
    }

    func confirmSymbolPicker() {
        let hit = symbolPicker.selected
        showSymbolPicker = false
        if let hit {
            HitNavigation.open(hit, state: self)
        }
    }

    func toggleProjectFind(field: ProjectFindField = .query) {
        if showProjectFind, projectFind.field != field {
            projectFind.field = field
            return
        }
        if toggleOverlay(.projectFind) {
            projectFind.field = field
        }
    }
}
