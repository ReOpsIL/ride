import AppKit

final class CompletionPopupLayout: NSView {
    static let listWidth: CGFloat = 520
    static let footerHeight: CGFloat = 20
    static let maxRows = 10
    static let topInset = Tokens.Space.xs
    static let searchHeight = PopupSearchBar.height + Tokens.Space.s
    static let hints = "↩ accept   ⇥ accept   esc dismiss   ⌘F search   ⌘click source   ⌘I docs"
    static let searchHints = "↩ accept   ↑↓ select   type to filter   esc end search"
    static var initialSize: NSSize {
        NSSize(width: listWidth, height: topInset + searchHeight + listHeight(rows: 1) + footerHeight)
    }

    let card = OverlayCardView()
    let scroll = NSScrollView()
    let doc = CompletionDocCard(frame: .zero)
    let searchBar = PopupSearchBar(placeholder: "Search names, signatures and docs")
    private let footer = NSTextField(labelWithString: CompletionPopupLayout.hints)
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
        footer.lineBreakMode = .byTruncatingTail
        card.addSubview(searchBar)
        card.addSubview(scroll)
        card.addSubview(doc)
        card.addSubview(footer)
        applyTheme()
        place()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func footer(truncated: Bool, search: PopupSearch) {
        if search.isActive {
            footer.stringValue = Self.searchHints
        } else {
            footer.stringValue = truncated ? "…more results, keep typing   ·   " + Self.hints : Self.hints
        }
    }

    func applyTheme() {
        card.applyTheme()
        footer.textColor = ThemeStore.shared.chrome.textTertiary
    }

    var docWidth: CGFloat {
        guard showsDoc else {
            return 0
        }
        return CompletionDocCard.width
    }

    static func listHeight(rows: Int) -> CGFloat {
        CGFloat(min(max(rows, 1), maxRows)) * Tokens.Size.completionRow
    }

    func size(rows: Int) -> NSSize {
        let body = Self.listHeight(rows: rows)
        return NSSize(width: Self.listWidth + docWidth, height: Self.topInset + Self.searchHeight + body + Self.footerHeight)
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
        let bodyHeight = bounds.height - Self.footerHeight - Self.topInset - Self.searchHeight
        let barY = bounds.height - Self.topInset - PopupSearchBar.height
        let inset = Tokens.Space.s
        searchBar.frame = NSRect(x: inset, y: barY, width: bounds.width - inset * 2, height: PopupSearchBar.height)
        scroll.frame = NSRect(x: 0, y: Self.footerHeight, width: Self.listWidth, height: bodyHeight)
        doc.isHidden = !showsDoc
        doc.frame = NSRect(x: Self.listWidth, y: Self.footerHeight, width: docWidth, height: bodyHeight)
        footer.frame = NSRect(x: Tokens.Space.l, y: 3, width: bounds.width - Tokens.Space.l * 2, height: 14)
    }
}
