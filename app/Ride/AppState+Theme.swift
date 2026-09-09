import AppKit

extension AppState {
    var isLightTheme: Bool {
        prefs.theme == "light"
    }

    func applyTheme() {
        ThemeStore.shared.apply(name: prefs.theme)
        NSApp.appearance = NSAppearance(named: isLightTheme ? .aqua : .darkAqua)
        if let view = EditorJump.shared.view {
            view.applyTheme(ThemeStore.shared.theme)
            EditorJump.shared.host?.applyTheme(ThemeStore.shared.theme)
            if let buffer = activeBuffer {
                SessionService.shared.resync(document: buffer, view: view)
            }
        }
    }
}
