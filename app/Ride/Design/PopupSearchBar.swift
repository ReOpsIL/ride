import AppKit

final class PopupSearchBar: NSView {
    static let height: CGFloat = 24
    static let iconWidth: CGFloat = 14
    let placeholder: String
    var onClick: (() -> Void)?
    private let icon = NSImageView()
    private let field = NSTextField(labelWithString: "")

    init(placeholder: String) {
        self.placeholder = placeholder + "   ⌘F"
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = Tokens.Radius.m
        layer?.cornerCurve = .continuous
        layer?.borderWidth = Tokens.Size.hairline
        icon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        field.font = Tokens.nsUI(11)
        field.lineBreakMode = .byTruncatingHead
        field.alignment = .left
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for view in [icon, field] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Tokens.Space.m),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: Self.iconWidth),
            field.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: Tokens.Space.s),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Tokens.Space.m),
            field.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func fill(_ search: PopupSearch) {
        let chrome = ThemeStore.shared.chrome
        layer?.backgroundColor = chrome.bgHover.cgColor
        layer?.borderColor = (search.isActive ? chrome.accent : chrome.border).cgColor
        icon.contentTintColor = search.isActive ? chrome.accent : chrome.textTertiary
        field.attributedStringValue = text(search, chrome: chrome)
    }

    private func text(_ search: PopupSearch, chrome: ChromeColors) -> NSAttributedString {
        let font = Tokens.nsUI(11)
        guard search.isActive else {
            return NSAttributedString(string: placeholder, attributes: [.font: font, .foregroundColor: chrome.textTertiary])
        }
        let out = NSMutableAttributedString(string: search.query, attributes: [.font: font, .foregroundColor: chrome.textPrimary])
        out.append(NSAttributedString(string: "▏", attributes: [.font: font, .foregroundColor: chrome.accent]))
        return out
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
