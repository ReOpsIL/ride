import AppKit

final class CompletionRowView: NSTableCellView {
    private let glyph = NSTextField(labelWithString: "")
    private let name = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let origin = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        glyph.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        glyph.alignment = .center
        name.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        name.textColor = .labelColor
        detail.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        origin.font = NSFont.systemFont(ofSize: 10)
        origin.textColor = .tertiaryLabelColor
        origin.alignment = .right
        for field in [glyph, name, detail, origin] {
            field.translatesAutoresizingMaskIntoConstraints = false
            addSubview(field)
        }
        name.setContentCompressionResistancePriority(.required, for: .horizontal)
        origin.setContentCompressionResistancePriority(.required, for: .horizontal)
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            glyph.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            glyph.widthAnchor.constraint(equalToConstant: 28),
            glyph.centerYAnchor.constraint(equalTo: centerYAnchor),
            name.leadingAnchor.constraint(equalTo: glyph.trailingAnchor, constant: 6),
            name.centerYAnchor.constraint(equalTo: centerYAnchor),
            detail.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: 10),
            detail.centerYAnchor.constraint(equalTo: centerYAnchor),
            origin.leadingAnchor.constraint(greaterThanOrEqualTo: detail.trailingAnchor, constant: 8),
            origin.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            origin.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func fill(_ hit: CompletionHit) {
        glyph.stringValue = CompletionRowStyle.glyph(hit.itemKind)
        glyph.textColor = CompletionRowStyle.color(hit.itemKind)
        name.stringValue = hit.name
        detail.stringValue = CompletionRowStyle.detail(hit)
        origin.stringValue = CompletionRowStyle.origin(hit)
        toolTip = hit.docFirstSentence.isEmpty ? nil : hit.docFirstSentence
    }
}
