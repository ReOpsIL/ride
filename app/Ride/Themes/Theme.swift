import AppKit

struct Theme {
    var keyword: NSColor
    var function: NSColor
    var type: NSColor
    var property: NSColor
    var variable: NSColor
    var constant: NSColor
    var string: NSColor
    var escape: NSColor
    var comment: NSColor
    var attribute: NSColor
    var lifetime: NSColor
    var macro: NSColor
    var number: NSColor
    var operatorColor: NSColor
    var punctuation: NSColor
    var label: NSColor
    var error: NSColor

    func color(_ kind: CaptureKind) -> NSColor {
        switch kind {
        case .keyword: return keyword
        case .function: return function
        case .type: return type
        case .property: return property
        case .variable: return variable
        case .constant: return constant
        case .string: return string
        case .escape: return escape
        case .comment: return comment
        case .attribute: return attribute
        case .lifetime: return lifetime
        case .macro: return macro
        case .number: return number
        case .`operator`: return operatorColor
        case .punctuation: return punctuation
        case .label: return label
        }
    }

    static func load() -> Theme {
        let url = Bundle.main.url(forResource: "dark", withExtension: "json")
        let data = url.flatMap { try? Data(contentsOf: $0) }
        let map = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] } ?? [:]
        func hex(_ key: String, fallback: String) -> NSColor {
            NSColor.fromHex(map[key] ?? fallback)
        }
        return Theme(
            keyword: hex("keyword", fallback: "#C586C0"),
            function: hex("function", fallback: "#DCDCAA"),
            type: hex("type", fallback: "#4EC9B0"),
            property: hex("property", fallback: "#9CDCFE"),
            variable: hex("variable", fallback: "#D4D4D4"),
            constant: hex("constant", fallback: "#4FC1FF"),
            string: hex("string", fallback: "#CE9178"),
            escape: hex("escape", fallback: "#D7BA7D"),
            comment: hex("comment", fallback: "#6A9955"),
            attribute: hex("attribute", fallback: "#C586C0"),
            lifetime: hex("lifetime", fallback: "#9CDCFE"),
            macro: hex("macro", fallback: "#DCDCAA"),
            number: hex("number", fallback: "#B5CEA8"),
            operatorColor: hex("operator", fallback: "#D4D4D4"),
            punctuation: hex("punctuation", fallback: "#D4D4D4"),
            label: hex("label", fallback: "#C8C8C8"),
            error: NSColor.systemRed.withAlphaComponent(0.85)
        )
    }
}

extension NSColor {
    static func fromHex(_ raw: String) -> NSColor {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") {
            s.removeFirst()
        }
        guard s.count == 6, let n = UInt32(s, radix: 16) else {
            return .textColor
        }
        let r = CGFloat((n >> 16) & 0xFF) / 255
        let g = CGFloat((n >> 8) & 0xFF) / 255
        let b = CGFloat(n & 0xFF) / 255
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
