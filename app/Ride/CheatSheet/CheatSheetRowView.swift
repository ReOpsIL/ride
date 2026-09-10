import AppKit

final class CheatSheetEntryView: NSTableCellView {
    private let name = NSTextField(labelWithString: "")
    private let doc = NSTextField(labelWithString: "")
    private let template = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        name.font = Tokens.nsMono(12, weight: .semibold)
        doc.font = Tokens.nsUI(11)
        doc.lineBreakMode = .byTruncatingTail
        template.font = Tokens.nsMono(10)
        template.lineBreakMode = .byTruncatingTail
        for field in [name, doc, template] {
            field.translatesAutoresizingMaskIntoConstraints = false
            addSubview(field)
        }
        name.setContentCompressionResistancePriority(.required, for: .horizontal)
        doc.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            name.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Tokens.Space.l),
            name.topAnchor.constraint(equalTo: topAnchor, constant: Tokens.Space.xs),
            doc.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: Tokens.Space.m),
            doc.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Tokens.Space.l),
            doc.firstBaselineAnchor.constraint(equalTo: name.firstBaselineAnchor),
            template.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            template.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Tokens.Space.l),
            template.topAnchor.constraint(equalTo: name.bottomAnchor, constant: Tokens.Space.xxs),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func fill(_ entry: CheatItem, prefix: String) {
        let chrome = ThemeStore.shared.chrome
        name.attributedStringValue = CompletionRowStyle.name(entry.name, prefix: prefix, chrome: chrome)
        doc.stringValue = entry.doc
        doc.textColor = chrome.textSecondary
        template.stringValue = SnippetParser.parse(entry.snippet).text.split(separator: "\n").joined(separator: " ⏎ ")
        template.textColor = chrome.textTertiary
    }
}

final class CheatSheetHeaderView: NSTableCellView {
    private let title = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        title.font = Tokens.nsUI(10, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Tokens.Space.l),
            title.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Tokens.Space.xxs),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func fill(title text: String, matched: Bool) {
        let chrome = ThemeStore.shared.chrome
        title.stringValue = matched ? text.uppercased() : text.uppercased() + "  ·  BY PREFIX"
        title.textColor = matched ? chrome.accent : chrome.textTertiary
    }
}
