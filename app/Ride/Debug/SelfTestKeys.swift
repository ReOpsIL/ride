import AppKit

enum SelfTestKeys {
    private static let specialCodes: [String: (UInt16, UInt32)] = [
        "space": (49, 0x20), "return": (36, 0x0D), "tab": (48, 0x09), "delete": (51, 0x7F),
        "forwardDelete": (117, 0xF728), "escape": (53, 0x1B),
        "left": (123, 0xF702), "right": (124, 0xF703), "down": (125, 0xF701), "up": (126, 0xF700),
        "F1": (122, 0xF704), "F2": (120, 0xF705), "F5": (96, 0xF708), "F6": (97, 0xF709), "F7": (98, 0xF70A),
        "F8": (100, 0xF70B), "F9": (101, 0xF70C), "F10": (109, 0xF70D), "F12": (111, 0xF70F),
        "minus": (27, 0x2D),
    ]

    private static let characterCodes: [Character: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
        "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
        "=": 24, "9": 25, "7": 26, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "l": 37, "j": 38, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "?": 44, "n": 45, "m": 46, ".": 47,
    ]

    static func event(_ combo: KeyCombo, window: NSWindow) -> NSEvent? {
        guard let (code, text) = codeAndText(combo) else {
            return nil
        }
        let flags = combo.key == "?" ? combo.modifiers.union(.shift).flags : combo.modifiers.flags
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: text,
            charactersIgnoringModifiers: text,
            isARepeat: false,
            keyCode: code
        )
    }

    @discardableResult
    static func post(_ keys: String, window: NSWindow?) -> Bool {
        guard let window, let combo = KeyCombo(glyphs: keys), let event = event(combo, window: window) else {
            return false
        }
        NSApp.postEvent(event, atStart: false)
        return true
    }

    private static func codeAndText(_ combo: KeyCombo) -> (UInt16, String)? {
        if let special = specialCodes[combo.key], let scalar = Unicode.Scalar(special.1) {
            return (special.0, String(Character(scalar)))
        }
        guard let character = combo.key.first, let code = characterCodes[character] else {
            return nil
        }
        return (code, combo.key)
    }

    static var mainWindow: NSWindow? {
        EditorPanes.shared.focusedView?.window ?? NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible && !($0 is NSPanel) }
    }
}

final class SelfTestKeyProbe: NSView {
    private(set) var received: [KeyCombo] = []

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if let combo = KeyCombo(event: event) {
            received.append(combo)
        }
    }

    func attach(to window: NSWindow?) -> Bool {
        guard let content = window?.contentView else {
            return false
        }
        frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        content.addSubview(self)
        return window?.makeFirstResponder(self) == true
    }

    func detach() {
        removeFromSuperview()
        received = []
    }
}
