import AppKit

enum SelfTestKey {
    case up
    case down
    case escape
    case enter
    case commandEnter
    case space(NSEvent.ModifierFlags)

    var code: UInt16 {
        switch self {
        case .up: 126
        case .down: 125
        case .escape: 53
        case .enter, .commandEnter: 36
        case .space: 49
        }
    }

    var characters: String {
        switch self {
        case .up: "\u{F700}"
        case .down: "\u{F701}"
        case .escape: "\u{1B}"
        case .enter, .commandEnter: "\r"
        case .space: " "
        }
    }

    var flags: NSEvent.ModifierFlags {
        switch self {
        case .space(let flags): flags
        case .commandEnter: .command
        default: []
        }
    }

    func event(in window: NSWindow?) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window?.windowNumber ?? 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: code
        )
    }

    func press(_ view: NSView?) {
        guard let view, let event = event(in: view.window) else {
            return
        }
        view.keyDown(with: event)
    }

    func sendToSheet(of window: NSWindow?) -> Bool {
        guard let sheet = window?.attachedSheet, let event = event(in: sheet) else {
            return false
        }
        if sheet.performKeyEquivalent(with: event) {
            return true
        }
        NSApp.sendEvent(event)
        return true
    }

    func reachesMainMenu(from window: NSWindow?) -> Bool {
        guard let event = event(in: window) else {
            return false
        }
        return NSApp.mainMenu?.performKeyEquivalent(with: event) ?? false
    }
}

enum SelfTestViews {
    static func button(in root: NSView?, where match: (NSButton) -> Bool) -> NSButton? {
        guard let root else {
            return nil
        }
        if let button = root as? NSButton, match(button) {
            return button
        }
        for child in root.subviews {
            if let found = button(in: child, where: match) {
                return found
            }
        }
        return nil
    }

    static func click(in root: NSView?, where match: (NSButton) -> Bool) -> Bool {
        guard let found = button(in: root, where: match) else {
            return false
        }
        found.performClick(nil)
        return true
    }
}

final class SelfTestStash {
    var original = ""
    var base = ""
    var probe = ""
    var before = ""
    var flag = false
}
