import AppKit

final class HoverPanel {
    let panel: NSPanel
    static let maxWidth: CGFloat = 520
    private let card = OverlayCardView()
    private let signature = NSTextField(wrappingLabelWithString: "")
    private let doc = NSTextField(wrappingLabelWithString: "")
    private let origin = NSTextField(labelWithString: "")
    var onClick: (() -> Void)?

    init() {
        panel = OverlayPanel.make(size: NSSize(width: 200, height: 40))
        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        card.addGestureRecognizer(click)
        signature.font = Tokens.nsMono(11)
        signature.maximumNumberOfLines = 6
        doc.font = Tokens.nsUI(11)
        doc.maximumNumberOfLines = 4
        origin.font = Tokens.nsMono(10)
        origin.lineBreakMode = .byTruncatingMiddle
        for view in [signature, doc, origin] {
            card.addSubview(view)
        }
        panel.contentView = card
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show(_ content: HoverContent, anchor: NSRect, bounds: NSRect) {
        let chrome = ThemeStore.shared.chrome
        card.applyTheme()
        signature.textColor = chrome.textPrimary
        doc.textColor = chrome.textSecondary
        origin.textColor = chrome.textTertiary
        signature.stringValue = content.signature
        doc.stringValue = content.doc
        origin.stringValue = content.origin
        let inset = Tokens.Space.l
        let textWidth = Self.maxWidth - inset * 2
        var y = inset
        var widest: CGFloat = 0
        let fields = [signature, doc, origin].filter { !$0.stringValue.isEmpty }
        for field in fields.reversed() {
            field.preferredMaxLayoutWidth = textWidth
            let size = field.sizeThatFits(NSSize(width: textWidth, height: 400))
            field.frame = NSRect(x: inset, y: y, width: size.width, height: size.height)
            widest = max(widest, size.width)
            y += size.height + Tokens.Space.m
        }
        signature.isHidden = signature.stringValue.isEmpty
        doc.isHidden = doc.stringValue.isEmpty
        let size = NSSize(width: widest + inset * 2, height: y - Tokens.Space.m + inset)
        OverlayPanel.present(panel, frame: Self.place(size: size, anchor: anchor, bounds: bounds))
    }

    static func place(size: NSSize, anchor: NSRect, bounds: NSRect) -> NSRect {
        var frame = NSRect(x: anchor.minX, y: anchor.maxY + Tokens.Space.xs, width: size.width, height: size.height)
        if frame.maxY > bounds.maxY {
            frame.origin.y = anchor.minY - size.height - Tokens.Space.xs
        }
        frame.origin.y = max(bounds.minY, frame.origin.y)
        if frame.maxX > bounds.maxX {
            frame.origin.x = max(bounds.minX, bounds.maxX - size.width)
        }
        return frame
    }

    func hide() {
        panel.orderOut(nil)
    }

    @objc private func clicked() {
        onClick?()
    }
}
