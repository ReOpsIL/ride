import AppKit
import Combine
import SwiftUI

final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published private(set) var theme = ThemeStore.adjusted(Theme.load())
    private var observer: NSObjectProtocol?

    var chrome: ChromeColors { theme.chrome }
    var editor: EditorColors { theme.editor }

    private init() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }
            self.apply(name: self.theme.name)
        }
    }

    func apply(name: String) {
        theme = Self.adjusted(Theme.load(name: name))
        HighlightApply.theme = theme
    }

    static func adjusted(_ theme: Theme) -> Theme {
        guard NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast else {
            return theme
        }
        var strong = theme
        let border = theme.chrome.border
        strong.chrome.border = border.withAlphaComponent(min(1, border.alphaComponent * 3))
        return strong
    }
}

extension Color {
    init(_ ns: NSColor) {
        self.init(nsColor: ns)
    }
}

struct ChromeStyle {
    let c: ChromeColors

    var bgBase: Color { Color(c.bgBase) }
    var bgRaised: Color { Color(c.bgRaised) }
    var bgOverlay: Color { Color(c.bgOverlay) }
    var bgHover: Color { Color(c.bgHover) }
    var bgSelection: Color { Color(c.bgSelection) }
    var border: Color { Color(c.border) }
    var textPrimary: Color { Color(c.textPrimary) }
    var textSecondary: Color { Color(c.textSecondary) }
    var textTertiary: Color { Color(c.textTertiary) }
    var accent: Color { Color(c.accent) }
    var error: Color { Color(c.error) }
    var warning: Color { Color(c.warning) }
    var info: Color { Color(c.info) }
    var success: Color { Color(c.success) }
}

extension ThemeStore {
    var ui: ChromeStyle { ChromeStyle(c: theme.chrome) }
    var editorBackground: Color { Color(theme.editor.background) }
}
