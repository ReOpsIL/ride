import Foundation

enum AnsiColor: Int, CaseIterable {
    case black = 0
    case red
    case green
    case yellow
    case blue
    case magenta
    case cyan
    case white
}

struct AnsiSpan: Equatable {
    var text: String
    var color: AnsiColor?
    var bold: Bool

    init(text: String, color: AnsiColor? = nil, bold: Bool = false) {
        self.text = text
        self.color = color
        self.bold = bold
    }
}

enum AnsiSpans {
    static func parse(_ text: String) -> [AnsiSpan] {
        var spans: [AnsiSpan] = []
        var current = AnsiSpan(text: "")
        var rest = Substring(text)
        while let escape = rest.firstIndex(of: "\u{1B}") {
            current.text += rest[rest.startIndex..<escape]
            guard let code = sequence(rest[escape...]) else {
                current.text.append("\u{1B}")
                rest = rest[rest.index(after: escape)...]
                continue
            }
            append(current, to: &spans)
            current = apply(code.params, to: current)
            current.text = ""
            rest = code.rest
        }
        current.text += rest
        append(current, to: &spans)
        return spans
    }

    static func plain(_ text: String) -> String {
        parse(text).map(\.text).joined()
    }

    private static func append(_ span: AnsiSpan, to spans: inout [AnsiSpan]) {
        guard !span.text.isEmpty else {
            return
        }
        if var last = spans.last, last.color == span.color, last.bold == span.bold {
            last.text += span.text
            spans[spans.count - 1] = last
            return
        }
        spans.append(span)
    }

    private static func sequence(_ text: Substring) -> (params: [Int], rest: Substring)? {
        var index = text.index(after: text.startIndex)
        guard index < text.endIndex, text[index] == "[" else {
            return nil
        }
        index = text.index(after: index)
        var digits = ""
        var params: [Int] = []
        while index < text.endIndex {
            let ch = text[index]
            index = text.index(after: index)
            if ch.isNumber {
                digits.append(ch)
            } else if ch == ";" {
                params.append(Int(digits) ?? 0)
                digits = ""
            } else if ch == "m" {
                params.append(Int(digits) ?? 0)
                return (params, text[index...])
            } else {
                return ([], text[index...])
            }
        }
        return nil
    }

    private static func apply(_ params: [Int], to span: AnsiSpan) -> AnsiSpan {
        var next = span
        for param in params {
            switch param {
            case 0:
                next.color = nil
                next.bold = false
            case 1:
                next.bold = true
            case 22:
                next.bold = false
            case 30...37:
                next.color = AnsiColor(rawValue: param - 30)
            case 39:
                next.color = nil
            case 90...97:
                next.color = AnsiColor(rawValue: param - 90)
                next.bold = true
            default:
                continue
            }
        }
        return next
    }
}
