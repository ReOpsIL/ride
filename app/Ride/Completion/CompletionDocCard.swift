import AppKit

final class CompletionDocCard: NSView {
    static let width: CGFloat = 300
    private let signature = NSTextField(wrappingLabelWithString: "")
    private let doc = NSTextField(wrappingLabelWithString: "")
    private let origin = NSTextField(labelWithString: "")
    private let separator = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        signature.font = Tokens.nsMono(11)
        signature.maximumNumberOfLines = 4
        doc.font = Tokens.nsUI(11)
        doc.maximumNumberOfLines = 8
        origin.font = Tokens.nsMono(10)
        origin.lineBreakMode = .byTruncatingMiddle
        separator.wantsLayer = true
        for view in [separator, signature, doc, origin] {
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
            origin.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
            origin.leadingAnchor.constraint(equalTo: signature.leadingAnchor),
            origin.trailingAnchor.constraint(equalTo: signature.trailingAnchor),
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
        guard let hit else {
            signature.stringValue = ""
            doc.stringValue = "No documentation"
            origin.stringValue = ""
            return
        }
        signature.stringValue = hit.signature
        let text = CompletionRowStyle.docText(hit)
        doc.stringValue = text.isEmpty ? "No documentation" : text
        origin.stringValue = hit.crateName.isEmpty ? hit.path : "\(hit.path) · \(hit.crateName)"
    }
}
