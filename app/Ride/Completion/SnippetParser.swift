import Foundation

struct SnippetStop: Equatable {
    let index: Int
    let range: NSRange
}

struct ParsedSnippet: Equatable {
    let text: String
    let stops: [SnippetStop]
    let finalOffset: Int
}

enum SnippetParser {
    static func parse(_ source: String) -> ParsedSnippet {
        var builder = Builder()
        let chars = Array(source)
        var i = 0
        while i < chars.count {
            if chars[i] == "\\", i + 1 < chars.count {
                builder.append(chars[i + 1])
                i += 2
            } else if chars[i] == "$", let stop = tabStop(chars, at: i + 1) {
                builder.record(index: stop.index, placeholder: stop.placeholder)
                i = stop.end
            } else {
                builder.append(chars[i])
                i += 1
            }
        }
        return builder.finish()
    }

    private struct TabStop {
        let index: Int
        let placeholder: String
        let end: Int
    }

    private static func tabStop(_ chars: [Character], at start: Int) -> TabStop? {
        guard start < chars.count else {
            return nil
        }
        if chars[start] == "{" {
            return braced(chars, at: start + 1)
        }
        let (index, end) = digits(chars, at: start)
        guard let index else {
            return nil
        }
        return TabStop(index: index, placeholder: "", end: end)
    }

    private static func braced(_ chars: [Character], at start: Int) -> TabStop? {
        let (index, afterDigits) = digits(chars, at: start)
        guard let index, afterDigits < chars.count else {
            return nil
        }
        if chars[afterDigits] == "}" {
            return TabStop(index: index, placeholder: "", end: afterDigits + 1)
        }
        guard chars[afterDigits] == ":" else {
            return nil
        }
        var placeholder = ""
        var i = afterDigits + 1
        while i < chars.count {
            if chars[i] == "\\", i + 1 < chars.count {
                placeholder.append(chars[i + 1])
                i += 2
                continue
            }
            if chars[i] == "}" {
                return TabStop(index: index, placeholder: placeholder, end: i + 1)
            }
            placeholder.append(chars[i])
            i += 1
        }
        return nil
    }

    private static func digits(_ chars: [Character], at start: Int) -> (Int?, Int) {
        var i = start
        var value = 0
        while i < chars.count, chars[i].isASCII, let digit = chars[i].wholeNumberValue {
            value = value * 10 + digit
            i += 1
        }
        return (i > start ? value : nil, i)
    }

    private struct Builder {
        var text = ""
        var stops: [SnippetStop] = []
        var finalOffset: Int?

        mutating func append(_ c: Character) {
            text.append(c)
        }

        mutating func record(index: Int, placeholder: String) {
            let start = text.utf16.count
            text += placeholder
            if index == 0 {
                if finalOffset == nil {
                    finalOffset = start
                }
            } else if !stops.contains(where: { $0.index == index }) {
                stops.append(SnippetStop(index: index, range: NSRange(location: start, length: placeholder.utf16.count)))
            }
        }

        func finish() -> ParsedSnippet {
            ParsedSnippet(
                text: text,
                stops: stops.sorted { $0.index < $1.index },
                finalOffset: finalOffset ?? text.utf16.count
            )
        }
    }
}
