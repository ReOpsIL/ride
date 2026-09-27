import AppKit

enum ModalPanels {
    static func chooseURL(_ panel: NSSavePanel) -> URL? {
        if let scripted = DialogScript.next(ScriptedURL.self) {
            return scripted.url
        }
        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url
    }
}
