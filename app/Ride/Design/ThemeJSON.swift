import AppKit

struct ThemeJSON {
    let map: [String: Any]

    init(map: [String: Any]) {
        self.map = map
    }

    static func load(name: String) -> ThemeJSON {
        let url = Bundle.main.url(forResource: name, withExtension: "json")
        let data = url.flatMap { try? Data(contentsOf: $0) }
        let map = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        return ThemeJSON(map: map)
    }

    func section(_ key: String) -> ThemeJSON {
        ThemeJSON(map: map[key] as? [String: Any] ?? [:])
    }

    func string(_ key: String) -> String? {
        map[key] as? String
    }

    func color(_ key: String, _ fallback: String) -> NSColor {
        NSColor.fromHex(string(key) ?? fallback)
    }
}

extension NSColor {
    static func fromHex(_ raw: String) -> NSColor {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") {
            s.removeFirst()
        }
        guard s.count == 6 || s.count == 8, let n = UInt64(s, radix: 16) else {
            return .textColor
        }
        let hasAlpha = s.count == 8
        let rgb = hasAlpha ? n >> 8 : n
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >> 8) & 0xFF) / 255
        let b = CGFloat(rgb & 0xFF) / 255
        let a = hasAlpha ? CGFloat(n & 0xFF) / 255 : 1
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
