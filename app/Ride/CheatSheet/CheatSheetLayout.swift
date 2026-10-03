import AppKit

final class CheatSheetLayout: NSView {
    static let listWidth: CGFloat = 300
    static let entryRow: CGFloat = 38
    static let headerRow: CGFloat = 22
    static let maxBody: CGFloat = 380
    static let minBody: CGFloat = 240
    static let footerHeight: CGFloat = 20
    static let topInset = Tokens.Space.xs
    static let searchHeight = PopupSearchBar.height + Tokens.Space.s

    enum Hints {
        case alone
        case shared
        case focused
        case searching

        var text: String {
            switch self {
            case .alone: return "↑↓ select   ↩ insert   click twice to insert   ⌥⇧space close"
            case .shared: return "⌥↑↓ or click to browse   ⌥↩ insert   ⌥⇧space pin   esc close"
            case .focused: return "↑↓ select   ↩ insert   click twice to insert   ⌘F search   esc close"
            case .searching: return "↑↓ select   ↩ insert   type to filter   esc end search"
            }
        }
    }

    let card = OverlayCardView()
    let scroll = NSScrollView()
    let preview = CheatSheetPreview(frame: .zero)
    let searchBar = PopupSearchBar(placeholder: "Search names, docs and snippets")
    private let footer = NSTextField(labelWithString: CheatSheetLayout.Hints.shared.text)

    static var initialSize: NSSize {
        NSSize(width: listWidth + CheatSheetPreview.width, height: topInset + searchHeight + entryRow + footerHeight)
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
        card.addSubview(searchBar)
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

    func setHints(_ hints: Hints) {
        footer.stringValue = hints.text
    }

    static func rowHeight(_ row: CheatRow) -> CGFloat {
        row.isEntry ? entryRow : headerRow
    }

    static func bodyHeight(rows: [CheatRow]) -> CGFloat {
        let list = rows.reduce(0) { $0 + rowHeight($1) }
        return min(max(list, minBody), maxBody)
    }

    func size(rows: [CheatRow]) -> NSSize {
        NSSize(
            width: Self.listWidth + CheatSheetPreview.width,
            height: Self.topInset + Self.searchHeight + Self.bodyHeight(rows: rows) + Self.footerHeight
        )
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
        preview.frame = NSRect(x: Self.listWidth, y: Self.footerHeight, width: CheatSheetPreview.width, height: bodyHeight)
        footer.frame = NSRect(x: Tokens.Space.l, y: 3, width: bounds.width - Tokens.Space.l * 2, height: 14)
    }
}
