import AppKit
import SwiftUI

enum ShortcutsPanel {
    private static var window: NSWindow?

    static func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingView(rootView: ShortcutsView())
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        let panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Keyboard Shortcuts"
        panel.contentView = hosting
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.appearance = NSAppearance(named: ThemeStore.shared.theme.isDark ? .darkAqua : .aqua)
        panel.backgroundColor = ThemeStore.shared.chrome.bgRaised
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        window = panel
    }
}
