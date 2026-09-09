import AppKit

final class CompletionPopupLayout: NSView {
    static let listWidth: CGFloat = 520
    static let footerHeight: CGFloat = 20
    static let maxRows = 10
    let card = OverlayCardView()
    let scroll = NSScrollView()
    let doc = CompletionDocCard(frame: .zero)
    private let footer = NSTextField(labelWithString: "↩ accept   ⇥ accept   esc dismiss   ⌘click source")
    var showsDoc = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        card.frame = bounds
        card.autoresizingMask = [.width, .height]
        addSubview(card)
        scroll.autoresizingMask = [.height]
        doc.autoresizingMask = [.height]
        footer.autoresizingMask = [.width, .maxYMargin]
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        footer.font = Tokens.nsUI(10)
        card.addSubview(scroll)
        card.addSubview(doc)
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

    static func size(rows: Int, doc: Bool) -> NSSize {
        let listHeight = CGFloat(min(max(rows, 1), maxRows)) * Tokens.Size.completionRow + Tokens.Space.xs * 2
        let width = listWidth + (doc ? CompletionDocCard.width : 0)
        return NSSize(width: width, height: listHeight + footerHeight)
    }

    override func layout() {
        super.layout()
        place()
    }

    private func place() {
        card.frame = bounds
        let listHeight = bounds.height - Self.footerHeight
        scroll.frame = NSRect(x: 0, y: Self.footerHeight, width: Self.listWidth, height: listHeight)
        doc.isHidden = !showsDoc
        doc.frame = NSRect(x: Self.listWidth, y: Self.footerHeight, width: CompletionDocCard.width, height: listHeight)
        footer.frame = NSRect(x: Tokens.Space.l, y: 3, width: bounds.width - Tokens.Space.l * 2, height: 14)
    }
}
