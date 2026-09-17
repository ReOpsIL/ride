import AppKit

extension AppState {
    var isLightTheme: Bool {
        prefs.theme == "light"
    }

    func applyTheme() {
        ThemeStore.shared.apply(name: prefs.theme)
        terminals.applyTheme(
            font: NSFont.monospacedSystemFont(ofSize: CGFloat(prefs.fontSize), weight: .regular),
            colors: TerminalColors.from(ThemeStore.shared.theme)
        )
        NSApp.appearance = NSAppearance(named: isLightTheme ? .aqua : .darkAqua)
        for host in EditorPanes.shared.all {
            host.textView.applyTheme(ThemeStore.shared.theme)
            host.applyTheme(ThemeStore.shared.theme)
            if let document = host.document {
                SessionService.shared.resync(document: document, view: host.textView)
            }
        }
    }
}
