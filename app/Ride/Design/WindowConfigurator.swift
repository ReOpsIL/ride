import AppKit
import SwiftUI

enum MainWindow {
    static weak var window: NSWindow?

    static func isOther(_ window: NSWindow) -> Bool {
        guard let main = self.window else {
            return false
        }
        return window !== main
    }
}

struct WindowConfigurator: NSViewRepresentable {
    @ObservedObject private var ts = ThemeStore.shared

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        view.window?.isRestorable = false
        guard let window = view.window, window.backgroundColor != ts.chrome.bgBase else {
            return
        }
        window.backgroundColor = ts.chrome.bgBase
        window.appearance = NSAppearance(named: ts.theme.isDark ? .darkAqua : .aqua)
    }

    private func configure(_ window: NSWindow?) {
        guard let window else {
            return
        }
        MainWindow.window = window
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unifiedCompact
        window.backgroundColor = ts.chrome.bgBase
        window.isOpaque = true
        window.minSize = NSSize(width: 860, height: 520)
        window.appearance = NSAppearance(named: ts.theme.isDark ? .darkAqua : .aqua)
        window.isRestorable = false
    }
}
