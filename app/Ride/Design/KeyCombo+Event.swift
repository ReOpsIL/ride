import AppKit

extension KeyCombo {
    private static let keyCodes: [UInt16: String] = [
        49: "space", 36: "return", 76: "return", 48: "tab", 51: "delete", 117: "forwardDelete", 53: "escape",
        123: "left", 124: "right", 125: "down", 126: "up",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    init?(event: NSEvent) {
        guard event.type == .keyDown else {
            return nil
        }
        var modifiers = KeyModifiers(flags: event.modifierFlags)
        if let named = Self.keyCodes[event.keyCode] {
            self.init(key: named, modifiers: modifiers)
            return
        }
        guard let typed = event.charactersIgnoringModifiers?.lowercased(), typed.count == 1 else {
            return nil
        }
        let letter = typed.uppercased() != typed
        if modifiers.contains(.shift), !letter, let bare = event.characters(byApplyingModifiers: []), bare != typed {
            modifiers.remove(.shift)
        }
        self.init(key: typed == "-" ? "minus" : typed, modifiers: modifiers)
    }

    init?(item: NSMenuItem) {
        self.init(keyEquivalent: item.keyEquivalent, modifiers: KeyModifiers(flags: item.keyEquivalentModifierMask))
    }
}

extension KeyModifiers {
    init(flags: NSEvent.ModifierFlags) {
        var set: KeyModifiers = []
        if flags.contains(.control) { set.insert(.control) }
        if flags.contains(.option) { set.insert(.option) }
        if flags.contains(.shift) { set.insert(.shift) }
        if flags.contains(.command) { set.insert(.command) }
        self = set
    }

    var flags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.control) { flags.insert(.control) }
        if contains(.option) { flags.insert(.option) }
        if contains(.shift) { flags.insert(.shift) }
        if contains(.command) { flags.insert(.command) }
        return flags
    }
}
