import Foundation

enum SvgPage {
    static func matches(_ url: URL?) -> Bool {
        url?.pathExtension.lowercased() == "svg"
    }

    static func asDocument(_ accept: String?) -> Bool {
        guard let accept else {
            return false
        }
        let value = accept.lowercased()
        return value.contains("text/html") && !value.contains("image/")
    }

    static func document(_ source: String, background: String, dark: Bool) -> String {
        let scheme = dark ? "dark" : "light"
        let svg = inline(source)
        return """
        <!doctype html><html><head><meta charset="utf-8"><style>
        :root{color-scheme:\(scheme)}
        html,body{margin:0;background:\(background)}
        body{min-height:100vh;display:flex;align-items:center;justify-content:center}
        svg{max-width:100%;height:auto;min-width:0}
        </style></head><body>\(svg)</body></html>
        """
    }

    static func inline(_ source: String) -> String {
        var text = trim(source)
        if text.hasPrefix("\u{feff}") {
            text = trim(String(text.dropFirst()))
        }
        while let next = cut(text) {
            text = next
        }
        return text
    }

    private static func cut(_ text: String) -> String? {
        let leads: [(String, String)] = [("<?", "?>"), ("<!--", "-->"), ("<!doctype", ">")]
        for (prefix, end) in leads {
            guard text.lowercased().hasPrefix(prefix), let range = text.range(of: end) else {
                continue
            }
            return trim(String(text[range.upperBound...]))
        }
        return nil
    }

    private static func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
