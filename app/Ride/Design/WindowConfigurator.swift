import AppKit
import SwiftUI

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
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.backgroundColor = ts.chrome.bgBase
        window.isOpaque = true
        window.minSize = NSSize(width: 860, height: 520)
        window.appearance = NSAppearance(named: ts.theme.isDark ? .darkAqua : .aqua)
    }
}
