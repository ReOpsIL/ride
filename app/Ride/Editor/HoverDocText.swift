import Foundation

enum HoverDocText {
    static func plain(_ html: String) -> String {
        var out = ""
        var i = html.startIndex
        while i < html.endIndex {
            if html[i] == "<" {
                guard let tag = readTag(html, at: i) else {
                    out.append(html[i])
                    i = html.index(after: i)
                    continue
                }
                gap(tag.name, closing: tag.closing, into: &out)
                i = tag.end
            } else if html[i] == "&" {
                let entity = readEntity(html, at: i)
                out += entity.text
                i = entity.end
            } else {
                out.append(html[i])
                i = html.index(after: i)
            }
        }
        return tidy(out)
    }

    private static func gap(_ name: String, closing: Bool, into out: inout String) {
        if name == "br" {
            newline(&out)
            return
        }
        if name == "li", !closing {
            newline(&out)
            out += "• "
            return
        }
        if closing, blocks.contains(name) {
            newline(&out)
        }
    }

    private static let blocks: Set<String> = [
        "p", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "li", "ul", "ol", "blockquote", "tr",
    ]

    private static func newline(_ out: inout String) {
        if !out.hasSuffix("\n") {
            out.append("\n")
        }
    }

    private static func readTag(_ html: String, at start: String.Index) -> (name: String, closing: Bool, end: String.Index)? {
        var i = html.index(after: start)
        guard i < html.endIndex else {
            return nil
        }
        var closing = false
        if html[i] == "/" {
            closing = true
            i = html.index(after: i)
        }
        let nameStart = i
        while i < html.endIndex, html[i].isLetter || html[i].isNumber {
            i = html.index(after: i)
        }
        guard i > nameStart else {
            return skipBroken(html, from: start)
        }
        let name = html[nameStart..<i].lowercased()
        while i < html.endIndex, html[i] != ">" {
            i = html.index(after: i)
        }
        guard i < html.endIndex else {
            return nil
        }
        return (name, closing, html.index(after: i))
    }

    private static func skipBroken(_ html: String, from start: String.Index) -> (name: String, closing: Bool, end: String.Index)? {
        var i = html.index(after: start)
        while i < html.endIndex, html[i] != ">" {
            i = html.index(after: i)
        }
        guard i < html.endIndex else {
            return nil
        }
        return ("", false, html.index(after: i))
    }

    private static func readEntity(_ html: String, at start: String.Index) -> (text: String, end: String.Index) {
        var i = html.index(after: start)
        let begin = i
        var count = 0
        while i < html.endIndex, html[i] != ";", count < 8 {
            i = html.index(after: i)
            count += 1
        }
        guard i < html.endIndex, html[i] == ";" else {
            return ("&", html.index(after: start))
        }
        let body = String(html[begin..<i])
        return (decode(body), html.index(after: i))
    }

    private static func decode(_ body: String) -> String {
        switch body {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos", "#39": return "'"
        case "nbsp": return " "
        default:
            if body.hasPrefix("#"), let code = UInt32(body.dropFirst()), let scalar = UnicodeScalar(code) {
                return String(scalar)
            }
            return "&\(body);"
        }
    }

    private static func tidy(_ raw: String) -> String {
        var lines: [String] = []
        var blanks = 0
        for line in raw.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let trimmed = trimTrailing(String(line))
            if trimmed.isEmpty {
                blanks += 1
                if blanks == 1, !lines.isEmpty {
                    lines.append("")
                }
            } else {
                blanks = 0
                lines.append(trimmed)
            }
        }
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    private static func trimTrailing(_ text: String) -> String {
        String(text.reversed().drop(while: \.isWhitespace).reversed())
    }
}
