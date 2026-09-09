import Foundation

extension AppState {
    var previewAvailable: Bool {
        activeBuffer?.language == .markdown
    }

    var previewVisible: Bool {
        showPreview && previewAvailable
    }

    func togglePreview() {
        showPreview.toggle()
        if previewVisible {
            refreshPreview()
        }
    }

    func refreshPreview() {
        guard previewVisible, let buffer = activeBuffer else {
            return
        }
        preview.render(text: buffer.text)
    }

    func previewTextChanged(_ document: BufferDocument, text: String) {
        guard previewVisible, document.id == activeID else {
            return
        }
        preview.schedule(text: text)
    }

    func previewViewport(line: Int) {
        guard previewVisible, preview.visibleLine != line else {
            return
        }
        preview.visibleLine = line
    }
}
