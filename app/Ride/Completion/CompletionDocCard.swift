import AppKit

final class CompletionDocCard: NSView {
    static let width: CGFloat = 300
    static let wideWidth: CGFloat = 450
    private let signature = NSTextField(wrappingLabelWithString: "")
    private let doc = NSTextField(wrappingLabelWithString: "")
    private let origin = NSTextField(labelWithString: "")
    private let hint = NSTextField(labelWithString: "⌘-click to open")
    private let footer = NSStackView()
    private let separator = NSView()
    var expanded = false {
        didSet { doc.maximumNumberOfLines = expanded ? 0 : 8 }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        signature.font = Tokens.nsMono(11)
        signature.maximumNumberOfLines = 4
        doc.font = Tokens.nsUI(11)
        doc.maximumNumberOfLines = 8
        origin.font = Tokens.nsMono(10)
        origin.lineBreakMode = .byTruncatingMiddle
        hint.font = Tokens.nsUI(10)
        separator.wantsLayer = true
        footer.orientation = .vertical
        footer.alignment = .leading
        footer.spacing = Tokens.Space.xxs
        footer.addArrangedSubview(origin)
        footer.addArrangedSubview(hint)
        for view in [separator, signature, doc, footer] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        let inset = Tokens.Space.l
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.widthAnchor.constraint(equalToConstant: Tokens.Size.hairline),
            signature.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            signature.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            signature.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            doc.topAnchor.constraint(equalTo: signature.bottomAnchor, constant: Tokens.Space.m),
            doc.leadingAnchor.constraint(equalTo: signature.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: signature.trailingAnchor),
            doc.bottomAnchor.constraint(lessThanOrEqualTo: footer.topAnchor, constant: -Tokens.Space.m),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
            footer.leadingAnchor.constraint(equalTo: signature.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: signature.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func fill(_ hit: CompletionHit?) {
        let chrome = ThemeStore.shared.chrome
        separator.layer?.backgroundColor = chrome.border.cgColor
        signature.textColor = chrome.textPrimary
        doc.textColor = chrome.textSecondary
        origin.textColor = chrome.textTertiary
        hint.textColor = chrome.textTertiary
        guard let hit else {
            signature.stringValue = ""
            doc.stringValue = "No documentation"
            origin.stringValue = ""
            hint.isHidden = true
            return
        }
        signature.stringValue = hit.signature
        let text = CompletionRowStyle.docText(hit)
        doc.stringValue = text.isEmpty ? "No documentation" : text
        origin.stringValue = CompletionRowStyle.docOrigin(hit)
        hint.isHidden = hit.sourcePath == nil
    }

    func requiredHeight(width: CGFloat) -> CGFloat {
        let inset = Tokens.Space.l
        let textWidth = width - inset * 2
        var height = inset * 2 + origin.intrinsicContentSize.height
        if !hint.isHidden {
            height += hint.intrinsicContentSize.height + Tokens.Space.xxs
        }
        for field in [signature, doc] where !field.stringValue.isEmpty {
            field.preferredMaxLayoutWidth = textWidth
            height += field.sizeThatFits(NSSize(width: textWidth, height: 4000)).height + Tokens.Space.m
        }
        return height
    }
}
