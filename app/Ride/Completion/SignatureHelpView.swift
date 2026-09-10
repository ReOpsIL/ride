import AppKit

final class SignatureHelpView: NSView {
    static let maxWidth: CGFloat = 520
    private let card = OverlayCardView()
    private let label = NSTextField(wrappingLabelWithString: "")
    private let doc = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        card.frame = bounds
        card.autoresizingMask = [.width, .height]
        addSubview(card)
        label.font = Tokens.nsMono(11)
        label.maximumNumberOfLines = 3
        doc.font = Tokens.nsUI(11)
        doc.lineBreakMode = .byTruncatingTail
        card.addSubview(label)
        card.addSubview(doc)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func fill(_ help: SignatureHelp) -> NSSize {
        let chrome = ThemeStore.shared.chrome
        card.applyTheme()
        label.attributedStringValue = Self.attributed(help, chrome: chrome)
        doc.stringValue = Self.firstSentence(help.doc)
        doc.textColor = chrome.textSecondary
        doc.isHidden = doc.stringValue.isEmpty
        let inset = Tokens.Space.l
        let textWidth = Self.maxWidth - inset * 2
        label.preferredMaxLayoutWidth = textWidth
        let labelSize = label.sizeThatFits(NSSize(width: textWidth, height: 200))
        let docSize = doc.isHidden
            ? NSSize.zero
            : NSSize(width: min(doc.intrinsicContentSize.width, textWidth), height: doc.intrinsicContentSize.height)
        var y = inset
        if !doc.isHidden {
            doc.frame = NSRect(x: inset, y: y, width: docSize.width, height: docSize.height)
            y += docSize.height + Tokens.Space.xs
        }
        label.frame = NSRect(x: inset, y: y, width: labelSize.width, height: labelSize.height)
        return NSSize(width: max(labelSize.width, docSize.width) + inset * 2, height: y + labelSize.height + inset)
    }

    static func attributed(_ help: SignatureHelp, chrome: ChromeColors) -> NSAttributedString {
        let out = NSMutableAttributedString(
            string: help.label,
            attributes: [.font: Tokens.nsMono(11), .foregroundColor: chrome.textPrimary]
        )
        let index = Int(help.activeParameter)
        guard help.parameters.indices.contains(index) else {
            return out
        }
        let parameter = help.parameters[index]
        let range = Utf16.nsRange(in: help.label, startByte: parameter.startByte, endByte: parameter.endByte)
        guard NSMaxRange(range) <= out.length else {
            return out
        }
        out.addAttributes([.font: Tokens.nsMono(11, weight: .bold), .foregroundColor: chrome.accent], range: range)
        return out
    }

    static func firstSentence(_ doc: String) -> String {
        let line = doc.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        if let end = line.range(of: ". ") {
            return String(line[..<end.lowerBound]) + "."
        }
        return line
    }
}
