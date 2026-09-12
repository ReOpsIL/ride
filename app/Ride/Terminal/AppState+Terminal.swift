import AppKit

extension AppState {
    func newTerminal() {
        openTerminal(directory: workspaceRoot)
    }

    func openTerminal(directory: URL?) {
        showTerminal = true
        terminals.applyTheme(font: terminalFont(), colors: TerminalColors.from(ThemeStore.shared.theme))
        terminals.open(directory: directory?.path)
        terminals.focusSelected()
    }

    func selectTerminal(_ id: UUID) {
        terminals.select(id)
        terminals.focusSelected()
    }

    func toggleTerminal() {
        showTerminal.toggle()
        guard showTerminal else {
            return
        }
        if terminals.tabs.isEmpty {
            openTerminal(directory: workspaceRoot)
            return
        }
        terminals.focusSelected()
    }

    func stopTerminalsOnWorkspaceChange() {
        terminals.observeWorkspace($workspaceRoot)
    }

    private func terminalFont() -> NSFont {
        NSFont.monospacedSystemFont(ofSize: CGFloat(prefs.fontSize), weight: .regular)
    }
}
