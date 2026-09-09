import AppKit

final class CompletionRowView: NSTableCellView {
    private let badge = KindBadgeView(frame: .zero)
    private let name = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let origin = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        name.font = Tokens.nsMono(12, weight: .semibold)
        detail.font = Tokens.nsMono(11)
        detail.lineBreakMode = .byTruncatingTail
        origin.font = Tokens.nsUI(10)
        origin.alignment = .right
        for field in [badge, name, detail, origin] {
            field.translatesAutoresizingMaskIntoConstraints = false
            addSubview(field)
        }
        name.setContentCompressionResistancePriority(.required, for: .horizontal)
        origin.setContentCompressionResistancePriority(.required, for: .horizontal)
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Tokens.Space.m),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            name.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: Tokens.Space.m),
            name.centerYAnchor.constraint(equalTo: centerYAnchor),
            detail.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: Tokens.Space.l),
            detail.centerYAnchor.constraint(equalTo: centerYAnchor),
            origin.leadingAnchor.constraint(greaterThanOrEqualTo: detail.trailingAnchor, constant: Tokens.Space.m),
            origin.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Tokens.Space.l),
            origin.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func fill(_ hit: CompletionHit, prefix: String) {
        let chrome = ThemeStore.shared.chrome
        badge.fill(hit.itemKind)
        name.attributedStringValue = CompletionRowStyle.name(hit.name, prefix: prefix, chrome: chrome)
        detail.stringValue = CompletionRowStyle.detail(hit)
        detail.textColor = chrome.textSecondary
        origin.stringValue = CompletionRowStyle.origin(hit)
        origin.textColor = chrome.textTertiary
    }
}
