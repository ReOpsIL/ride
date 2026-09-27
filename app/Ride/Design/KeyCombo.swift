import Foundation

struct KeyModifiers: OptionSet, Hashable {
    let rawValue: Int

    static let control = KeyModifiers(rawValue: 1)
    static let option = KeyModifiers(rawValue: 2)
    static let shift = KeyModifiers(rawValue: 4)
    static let command = KeyModifiers(rawValue: 8)

    static let glyphs: [(KeyModifiers, Character)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
}

struct KeyCombo: Hashable, CustomStringConvertible {
    let key: String
    let modifiers: KeyModifiers

    init(key: String, modifiers: KeyModifiers) {
        let single = key.count == 1 ? key : ""
        let shifted = single.uppercased() != single.lowercased() && single == single.uppercased()
        self.key = shifted ? single.lowercased() : key
        self.modifiers = shifted ? modifiers.union(.shift) : modifiers
    }

    init?(glyphs: String) {
        var modifiers: KeyModifiers = []
        var rest = Substring(glyphs.trimmingCharacters(in: .whitespaces))
        while let first = rest.first, let match = KeyModifiers.glyphs.first(where: { $0.1 == first }), rest.count > 1 {
            modifiers.insert(match.0)
            rest = rest.dropFirst()
        }
        guard let key = KeyNames.key(forGlyph: String(rest)) else {
            return nil
        }
        self.init(key: key, modifiers: modifiers)
    }

    init?(keyEquivalent: String, modifiers: KeyModifiers) {
        guard let scalar = keyEquivalent.unicodeScalars.first, keyEquivalent.unicodeScalars.count == 1 else {
            return nil
        }
        self.init(key: KeyNames.key(forScalar: scalar), modifiers: modifiers)
    }

    var description: String {
        let prefix = KeyModifiers.glyphs.filter { modifiers.contains($0.0) }.map { String($0.1) }.joined()
        return prefix + KeyNames.glyph(forKey: key)
    }
}

enum KeyNames {
    static let named: [(key: String, glyph: String, scalars: [UInt32])] = [
        ("space", "Space", [0x20]),
        ("return", "↩", [0x0D, 0x03]),
        ("tab", "⇥", [0x09, 0x19]),
        ("delete", "⌫", [0x08, 0x7F]),
        ("forwardDelete", "⌦", [0xF728]),
        ("escape", "esc", [0x1B]),
        ("up", "↑", [0xF700]),
        ("down", "↓", [0xF701]),
        ("left", "←", [0xF702]),
        ("right", "→", [0xF703]),
        ("minus", "−", [0x2D]),
    ]

    static let firstFunctionKey: UInt32 = 0xF704

    static func key(forScalar scalar: Unicode.Scalar) -> String {
        if let entry = named.first(where: { $0.scalars.contains(scalar.value) }) {
            return entry.key
        }
        if (firstFunctionKey..<firstFunctionKey + 35).contains(scalar.value) {
            return "F\(scalar.value - firstFunctionKey + 1)"
        }
        return String(Character(scalar))
    }

    static func key(forGlyph glyph: String) -> String? {
        if let entry = named.first(where: { $0.glyph == glyph }) {
            return entry.key
        }
        if glyph == "-" {
            return "minus"
        }
        if glyph.count > 1, glyph.first == "F", Int(glyph.dropFirst()) != nil {
            return glyph
        }
        return glyph.count == 1 ? glyph.lowercased() : nil
    }

    static func glyph(forKey key: String) -> String {
        named.first(where: { $0.key == key })?.glyph ?? key.uppercased()
    }
}
