import AppKit

final class CompletionPopupLayout: NSView {
    static let listWidth: CGFloat = 520
    static let footerHeight: CGFloat = 20
    static let maxRows = 10
    static let maxWideHeight: CGFloat = 420
    static let topInset = Tokens.Space.xs
    static let hints = "↩ accept   ⇥ accept   esc dismiss   ⌘click source   ⌘I docs"
    static var initialSize: NSSize {
        NSSize(width: listWidth, height: topInset + listHeight(rows: 1) + footerHeight)
    }

    let card = OverlayCardView()
    let scroll = NSScrollView()
    let doc = CompletionDocCard(frame: .zero)
    private let footer = NSTextField(labelWithString: CompletionPopupLayout.hints)
    var showsDoc = false
    var wide = false {
        didSet { doc.expanded = wide }
    }
    var truncated = false {
        didSet { footer.stringValue = truncated ? "…more results, keep typing   ·   " + Self.hints : Self.hints }
    }

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
        footer.lineBreakMode = .byTruncatingTail
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

    var docWidth: CGFloat {
        guard showsDoc else {
            return 0
        }
        return wide ? CompletionDocCard.wideWidth : CompletionDocCard.width
    }

    static func listHeight(rows: Int) -> CGFloat {
        CGFloat(min(max(rows, 1), maxRows)) * Tokens.Size.completionRow
    }

    func size(rows: Int) -> NSSize {
        var body = Self.listHeight(rows: rows)
        if showsDoc, wide {
            body = min(max(body, doc.requiredHeight(width: docWidth)), Self.maxWideHeight)
        }
        return NSSize(width: Self.listWidth + docWidth, height: Self.topInset + body + Self.footerHeight)
    }

    func configureScrolling(rows: Int) {
        let scrolls = rows > Self.maxRows
        scroll.hasVerticalScroller = scrolls
        scroll.verticalScrollElasticity = scrolls ? .allowed : .none
        scroll.contentView.scroll(to: .zero)
    }

    override func layout() {
        super.layout()
        place()
    }

    private func place() {
        card.frame = bounds
        let bodyHeight = bounds.height - Self.footerHeight - Self.topInset
        scroll.frame = NSRect(x: 0, y: Self.footerHeight, width: Self.listWidth, height: bodyHeight)
        doc.isHidden = !showsDoc
        doc.frame = NSRect(x: Self.listWidth, y: Self.footerHeight, width: docWidth, height: bodyHeight)
        footer.frame = NSRect(x: Tokens.Space.l, y: 3, width: bounds.width - Tokens.Space.l * 2, height: 14)
    }
}
