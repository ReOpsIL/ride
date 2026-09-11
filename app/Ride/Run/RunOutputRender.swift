import AppKit

enum RunOutputRender {
    static func line(_ raw: String, theme: Theme, fontSize: CGFloat) -> NSAttributedString {
        let spans = AnsiSpans.parse(raw)
        let out = NSMutableAttributedString()
        for span in spans {
            let font = Tokens.nsMono(fontSize, weight: span.bold ? .semibold : .regular)
            let color = span.color.map { self.color($0, theme: theme) } ?? theme.chrome.textPrimary
            out.append(NSAttributedString(string: span.text, attributes: [.font: font, .foregroundColor: color]))
        }
        for link in ConsoleLinks.links(in: out.string) {
            out.addAttributes(
                [
                    .link: encode(link),
                    .foregroundColor: theme.chrome.accent,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .cursor: NSCursor.pointingHand,
                ],
                range: NSRange(location: link.start, length: link.length)
            )
        }
        return out
    }

    static func color(_ ansi: AnsiColor, theme: Theme) -> NSColor {
        switch ansi {
        case .black:
            return theme.chrome.textTertiary
        case .red:
            return theme.chrome.error
        case .green:
            return theme.chrome.success
        case .yellow:
            return theme.chrome.warning
        case .blue:
            return theme.chrome.accent
        case .magenta:
            return theme.keyword
        case .cyan:
            return theme.type
        case .white:
            return theme.chrome.textPrimary
        }
    }

    static func encode(_ link: ConsoleLink) -> String {
        "\(link.path)\t\(link.line)\t\(link.column ?? 0)"
    }

    static func decode(_ value: String) -> ConsoleLink? {
        let parts = value.components(separatedBy: "\t")
        guard parts.count == 3, let line = Int(parts[1]), let column = Int(parts[2]) else {
            return nil
        }
        return ConsoleLink(path: parts[0], line: line, column: column == 0 ? nil : column, start: 0, length: 0)
    }
}
