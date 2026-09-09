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
        closeOverlays()
        showSymbolInFile.toggle()
        if showSymbolInFile {
            symbolQuery = ""
            symbolSelection = activeBuffer?.outline.first?.startByte
        }
    }

    func toggleSymbolPicker() {
        let next = !showSymbolPicker
        closeOverlays()
        showSymbolPicker = next
        if next {
            symbolPicker.reset()
        }
    }

    func toggleProjectFind() {
        let next = !showProjectFind
        closeOverlays()
        showProjectFind = next
    }

    func closeOverlays() {
        showQuickOpen = false
        showFind = false
        showSymbolInFile = false
        showSymbolPicker = false
        showProjectFind = false
    }
}
