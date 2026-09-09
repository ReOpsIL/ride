import AppKit

extension AppState {
    var isLightTheme: Bool {
        prefs.theme == "light"
    }

    func applyTheme() {
        HighlightApply.theme = Theme.load(name: prefs.theme)
        NSApp.appearance = NSAppearance(named: isLightTheme ? .aqua : .darkAqua)
        if let view = EditorJump.shared.view, let buffer = activeBuffer {
            SessionService.shared.resync(document: buffer, view: view)
        }
    }
}
