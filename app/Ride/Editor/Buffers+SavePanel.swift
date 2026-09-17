import AppKit

extension AppState {
    func chooseSaveURL(for buffer: BufferDocument) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.directoryURL = buffer.fileURL?.deletingLastPathComponent() ?? workspaceRoot
        panel.nameFieldStringValue = buffer.fileURL?.lastPathComponent ?? buffer.displayName + "." + buffer.language.fileExtension
        let picker = SaveLanguagePicker(panel: panel, initial: buffer.language)
        let response = withExtendedLifetime(picker) { panel.runModal() }
        guard response == .OK, let url = panel.url else {
            return nil
        }
        return url.standardizedFileURL
    }

    func rebind(_ buffer: BufferDocument, to url: URL) {
        let previous = buffer.language
        buffer.fileURL = url
        buffer.detectedLanguage = nil
        buffer.isReadOnly = false
        guard let host = EditorPanes.shared.host(bound: buffer) else {
            return
        }
        host.capture()
        if buffer.language != previous {
            SessionService.shared.close(buffer)
            SessionService.shared.attach(document: buffer, view: host.textView)
        }
    }
}
