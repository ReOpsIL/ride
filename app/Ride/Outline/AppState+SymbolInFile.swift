import Foundation

extension AppState {
    static let symbolInFileLimit = 60

    func toggleSymbolInFile() {
        guard toggleOverlay(.symbolInFile) else {
            return
        }
        symbolQuery = ""
        symbolSelection = symbolRows.first?.startByte
    }

    var symbolRows: [OutlineRow] {
        let all = activeBuffer?.outline ?? []
        let q = symbolQuery.lowercased()
        let matching = q.isEmpty ? all : all.filter { $0.name.lowercased().contains(q) || $0.kindLabel.contains(q) }
        return Array(matching.prefix(Self.symbolInFileLimit))
    }

    var symbolSelectionIndex: Int? {
        symbolRows.firstIndex { $0.startByte == symbolSelection }
    }

    func symbolQueryChanged() {
        symbolSelection = symbolRows.first?.startByte
    }

    func moveSymbolSelection(_ delta: Int) {
        let rows = symbolRows
        guard !rows.isEmpty else {
            return
        }
        let current = symbolSelectionIndex ?? 0
        symbolSelection = rows[(current + delta + rows.count) % rows.count].startByte
    }

    func confirmSymbolInFile() {
        let byte = symbolSelection ?? symbolRows.first?.startByte
        showSymbolInFile = false
        if let byte {
            jumpTo(byte: byte)
        }
    }
}
