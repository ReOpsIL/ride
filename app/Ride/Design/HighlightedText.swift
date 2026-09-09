import SwiftUI

enum HighlightedText {
    static func name(_ text: String, query: String, base: Color, accent: Color, font: Font) -> Text {
        build(text, ranges: MatchHighlight.ranges(in: text, query: query), base: base, font: font) { piece in
            Text(piece).foregroundColor(accent).font(font)
        }
    }

    static func marks(_ text: String, query: String, base: Color, mark: Color, font: Font) -> Text {
        var attributed = AttributedString(text)
        attributed.font = font
        attributed.foregroundColor = base
        for range in MatchHighlight.substrings(in: text, query: query) {
            if let r = Range(range, in: attributed) {
                attributed[r].backgroundColor = mark
            }
        }
        return Text(attributed)
    }

    private static func build(_ text: String, ranges: [NSRange], base: Color, font: Font, mark: (String) -> Text) -> Text {
        let ns = text as NSString
        var result = Text("")
        var cursor = 0
        for range in ranges {
            if range.location > cursor {
                result = result + Text(ns.substring(with: NSRange(location: cursor, length: range.location - cursor))).foregroundColor(base).font(font)
            }
            result = result + mark(ns.substring(with: range))
            cursor = NSMaxRange(range)
        }
        if cursor < ns.length {
            result = result + Text(ns.substring(from: cursor)).foregroundColor(base).font(font)
        }
        return result
    }
}
