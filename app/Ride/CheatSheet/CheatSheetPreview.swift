import AppKit

final class CheatSheetPreview: NSView {
    static let width: CGFloat = 230
    private let separator = NSView()
    private let code = NSTextField(wrappingLabelWithString: "")
    private let doc = NSTextField(wrappingLabelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        separator.wantsLayer = true
        code.font = Tokens.nsMono(11)
        code.maximumNumberOfLines = 12
        doc.font = Tokens.nsUI(11)
        doc.maximumNumberOfLines = 6
        for view in [separator, code, doc] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        let inset = Tokens.Space.l
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.widthAnchor.constraint(equalToConstant: Tokens.Size.hairline),
            code.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            code.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            code.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            doc.topAnchor.constraint(equalTo: code.bottomAnchor, constant: Tokens.Space.m),
            doc.leadingAnchor.constraint(equalTo: code.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: code.trailingAnchor),
            doc.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -inset),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func fill(_ entry: CheatItem?) {
        let chrome = ThemeStore.shared.chrome
        separator.layer?.backgroundColor = chrome.border.cgColor
        doc.textColor = chrome.textSecondary
        guard let entry else {
            code.stringValue = ""
            doc.stringValue = "No template"
            return
        }
        code.attributedStringValue = Self.highlighted(entry.snippet, chrome: chrome)
        doc.stringValue = entry.doc
    }

    static func highlighted(_ snippet: String, chrome: ChromeColors) -> NSAttributedString {
        let parsed = SnippetParser.parse(snippet)
        let out = NSMutableAttributedString(
            string: parsed.text,
            attributes: [.font: Tokens.nsMono(11), .foregroundColor: chrome.textPrimary]
        )
        for stop in parsed.stops where stop.range.length > 0 {
            out.addAttributes([
                .foregroundColor: chrome.accent,
                .backgroundColor: chrome.accent.withAlphaComponent(0.14),
            ], range: stop.range)
        }
        return out
    }
}
