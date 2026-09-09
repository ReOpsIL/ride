import AppKit
import SwiftUI

enum Tokens {
    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 6
        static let m: CGFloat = 8
        static let l: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
    }

    enum Radius {
        static let s: CGFloat = 4
        static let m: CGFloat = 6
        static let l: CGFloat = 8
        static let xl: CGFloat = 12
        static let card: CGFloat = 10
    }

    enum Size {
        static let hairline: CGFloat = 1
        static let sidebarRow: CGFloat = 22
        static let tab: CGFloat = 34
        static let statusBar: CGFloat = 24
        static let panelHeader: CGFloat = 28
        static let iconS: CGFloat = 11
        static let iconM: CGFloat = 13
        static let iconL: CGFloat = 16
        static let pickerRow: CGFloat = 26
        static let completionRow: CGFloat = 24
        static let badge: CGFloat = 16
    }

    enum Shadow {
        static let overlay = (radius: CGFloat(24), y: CGFloat(8), opacity: 0.35)
        static let popover = (radius: CGFloat(12), y: CGFloat(4), opacity: 0.25)
    }

    static func ui(_ size: CGFloat = 12, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat = 12, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func nsUI(_ size: CGFloat = 12, weight: NSFont.Weight = .regular) -> NSFont {
        .systemFont(ofSize: size, weight: weight)
    }

    static func nsMono(_ size: CGFloat = 12, weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: weight)
    }
}
