import AppKit

final class CompletionRowView: NSTableCellView {
    private let badge = KindBadgeView(frame: .zero)
    private let name = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let useTag = CompletionTagView(text: "use")
    private let origin = NSTextField(labelWithString: "")
    private let trailing = NSStackView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        name.font = Tokens.nsMono(12, weight: .semibold)
        detail.font = Tokens.nsMono(11)
        detail.lineBreakMode = .byTruncatingTail
        origin.font = Tokens.nsUI(10)
        origin.alignment = .right
        trailing.orientation = .horizontal
        trailing.spacing = Tokens.Space.s
        trailing.addArrangedSubview(useTag)
        trailing.addArrangedSubview(origin)
        for field in [badge, name, detail, trailing] {
            field.translatesAutoresizingMaskIntoConstraints = false
            addSubview(field)
        }
        name.setContentCompressionResistancePriority(.required, for: .horizontal)
        origin.setContentCompressionResistancePriority(.required, for: .horizontal)
        trailing.setContentCompressionResistancePriority(.required, for: .horizontal)
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Tokens.Space.m),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            name.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: Tokens.Space.m),
            name.centerYAnchor.constraint(equalTo: centerYAnchor),
            detail.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: Tokens.Space.l),
            detail.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailing.leadingAnchor.constraint(greaterThanOrEqualTo: detail.trailingAnchor, constant: Tokens.Space.m),
            trailing.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Tokens.Space.l),
            trailing.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func fill(_ hit: CompletionHit, prefix: String) {
        let chrome = ThemeStore.shared.chrome
        badge.fill(hit.itemKind)
        name.attributedStringValue = CompletionRowStyle.name(hit.name, prefix: prefix, chrome: chrome, deprecated: hit.deprecated)
        detail.stringValue = CompletionRowStyle.detail(hit)
        detail.textColor = chrome.textSecondary
        useTag.isHidden = hit.importPath == nil
        useTag.apply(chrome)
        origin.stringValue = CompletionRowStyle.origin(hit)
        origin.textColor = chrome.textTertiary
    }
}

final class CompletionTagView: NSView {
    private let label: NSTextField

    init(text: String) {
        label = NSTextField(labelWithString: text)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = Tokens.Radius.s
        layer?.cornerCurve = .continuous
        label.font = Tokens.nsUI(9, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Tokens.Space.xs),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Tokens.Space.xs),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func apply(_ chrome: ChromeColors) {
        label.textColor = chrome.accent
        layer?.backgroundColor = chrome.accent.withAlphaComponent(0.18).cgColor
    }
}
