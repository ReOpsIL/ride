import AppKit

extension AppState {
    var isLightTheme: Bool {
        prefs.theme == "light"
    }

    func applyTheme() {
        ThemeStore.shared.apply(name: prefs.theme)
        NSApp.appearance = NSAppearance(named: isLightTheme ? .aqua : .darkAqua)
        if let view = EditorPanes.shared.focusedView {
            view.applyTheme(ThemeStore.shared.theme)
            EditorPanes.shared.focused?.applyTheme(ThemeStore.shared.theme)
            if let buffer = activeBuffer {
                SessionService.shared.resync(document: buffer, view: view)
            }
        }
    }
}
