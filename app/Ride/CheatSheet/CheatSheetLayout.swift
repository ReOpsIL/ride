import AppKit

final class CheatSheetLayout: NSView {
    static let listWidth: CGFloat = 300
    static let entryRow: CGFloat = 38
    static let headerRow: CGFloat = 22
    static let maxBody: CGFloat = 320
    static let footerHeight: CGFloat = 20
    static let topInset = Tokens.Space.xs
    static let sharedHints = "⌥↑↓ select   ⌥↩ insert   ⌃⇧space pin   esc close"
    static let aloneHints = "↑↓ select   ↩ insert   ⌃⇧space close"

    let card = OverlayCardView()
    let scroll = NSScrollView()
    let preview = CheatSheetPreview(frame: .zero)
    private let footer = NSTextField(labelWithString: CheatSheetLayout.sharedHints)

    static var initialSize: NSSize {
        NSSize(width: listWidth + CheatSheetPreview.width, height: topInset + entryRow + footerHeight)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        card.frame = bounds
        card.autoresizingMask = [.width, .height]
        addSubview(card)
        scroll.autoresizingMask = [.height]
        preview.autoresizingMask = [.height]
        footer.autoresizingMask = [.width, .maxYMargin]
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        footer.font = Tokens.nsUI(10)
        footer.lineBreakMode = .byTruncatingTail
        card.addSubview(scroll)
        card.addSubview(preview)
        card.addSubview(footer)
        applyTheme()
        place()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func applyTheme() {
        card.applyTheme()
        footer.textColor = ThemeStore.shared.chrome.textTertiary
    }

    func setHints(shared: Bool) {
        footer.stringValue = shared ? Self.sharedHints : Self.aloneHints
    }

    static func rowHeight(_ row: CheatRow) -> CGFloat {
        row.isEntry ? entryRow : headerRow
    }

    static func bodyHeight(rows: [CheatRow]) -> CGFloat {
        min(max(rows.reduce(0) { $0 + rowHeight($1) }, entryRow), maxBody)
    }

    func size(rows: [CheatRow]) -> NSSize {
        NSSize(
            width: Self.listWidth + CheatSheetPreview.width,
            height: Self.topInset + Self.bodyHeight(rows: rows) + Self.footerHeight
        )
    }

    override func layout() {
        super.layout()
        place()
    }

    private func place() {
        card.frame = bounds
        let bodyHeight = bounds.height - Self.footerHeight - Self.topInset
        scroll.frame = NSRect(x: 0, y: Self.footerHeight, width: Self.listWidth, height: bodyHeight)
        preview.frame = NSRect(x: Self.listWidth, y: Self.footerHeight, width: CheatSheetPreview.width, height: bodyHeight)
        footer.frame = NSRect(x: Tokens.Space.l, y: 3, width: bounds.width - Tokens.Space.l * 2, height: 14)
    }
}
