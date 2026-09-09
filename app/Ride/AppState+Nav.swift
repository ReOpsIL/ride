import Foundation

extension AppState {
    func nextQueryId() -> UInt64 {
        queryCounter += 1
        latestQueryId = queryCounter
        return latestQueryId
    }

    func jumpTo(byte: UInt32) {
        EditorJump.shared.jump(byte: byte)
    }

    func toggleSymbolInFile() {
        showQuickOpen = false
        showFind = false
        showSymbolInFile.toggle()
        if showSymbolInFile {
            symbolQuery = ""
            symbolSelection = activeBuffer?.outline.first?.startByte
        }
    }
}
