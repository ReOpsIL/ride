import AppKit

final class HoverPanel {
    let panel: NSPanel
    static let maxWidth: CGFloat = 520
    static let maxDocHeight: CGFloat = 320
    private let card = OverlayCardView()
    private let signature = NSTextField(wrappingLabelWithString: "")
    private let scroll = NSScrollView()
    private let doc = HoverDocView()
    private let origin = NSTextField(labelWithString: "")
    private let exitWatch = HoverMouseWatch()
    var onClick: (() -> Void)?
    var onMouseExit: (() -> Void)?

    init() {
        panel = OverlayPanel.make(size: NSSize(width: 200, height: 40))
        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        card.addGestureRecognizer(click)
        signature.font = Tokens.nsMono(11)
        signature.maximumNumberOfLines = 6
        origin.font = Tokens.nsMono(10)
        origin.lineBreakMode = .byTruncatingMiddle
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.scrollerStyle = .overlay
        scroll.documentView = doc
        exitWatch.onExit = { [weak self] in
            self?.onMouseExit?()
        }
        for view in [signature, scroll, origin, exitWatch] {
            card.addSubview(view)
        }
        panel.contentView = card
    }

    var isVisible: Bool {
        panel.isVisible
    }

    var screenFrame: NSRect {
        panel.frame
    }

    func containsMouse() -> Bool {
        guard panel.isVisible else {
            return false
        }
        return panel.frame.insetBy(dx: -8, dy: -8).contains(NSEvent.mouseLocation)
    }

    func show(_ content: HoverContent, anchor: NSRect, bounds: NSRect) {
        let chrome = ThemeStore.shared.chrome
        card.applyTheme()
        signature.textColor = chrome.textPrimary
        origin.textColor = chrome.textTertiary
        signature.stringValue = content.signature
        origin.stringValue = content.origin
        doc.fill(content.doc, color: chrome.textSecondary)
        let inset = Tokens.Space.l
        let textWidth = Self.maxWidth - inset * 2
        var y = inset
        var widest = CGFloat(0)
        y = place(origin, y: y, width: textWidth, widest: &widest)
        y = placeDoc(y: y, width: textWidth, limit: docLimit(bounds), widest: &widest)
        y = place(signature, y: y, width: textWidth, widest: &widest)
        signature.isHidden = signature.stringValue.isEmpty
        origin.isHidden = origin.stringValue.isEmpty
        scroll.isHidden = content.doc.isEmpty
        let size = NSSize(width: max(widest, 40) + inset * 2, height: y - Tokens.Space.m + inset)
        OverlayPanel.present(panel, frame: Self.place(size: size, anchor: anchor, bounds: bounds))
        exitWatch.frame = card.bounds
        exitWatch.updateTrackingAreas()
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

    private func place(_ field: NSTextField, y: CGFloat, width: CGFloat, widest: inout CGFloat) -> CGFloat {
        guard !field.stringValue.isEmpty else {
            return y
        }
        field.preferredMaxLayoutWidth = width
        let size = field.sizeThatFits(NSSize(width: width, height: 400))
        field.frame = NSRect(x: Tokens.Space.l, y: y, width: size.width, height: size.height)
        widest = max(widest, size.width)
        return y + size.height + Tokens.Space.m
    }

    private func placeDoc(y: CGFloat, width: CGFloat, limit: CGFloat, widest: inout CGFloat) -> CGFloat {
        guard !doc.string.isEmpty else {
            return y
        }
        let used = doc.used(maxWidth: width)
        let visible = min(used.height, limit)
        let box = used.height > limit ? width : min(width, max(used.width, 1))
        scroll.frame = NSRect(x: Tokens.Space.l, y: y, width: box, height: visible)
        doc.frame = NSRect(x: 0, y: 0, width: box, height: max(used.height, visible))
        scroll.contentView.scroll(to: .zero)
        widest = max(widest, box)
        return y + visible + Tokens.Space.m
    }

    private func docLimit(_ bounds: NSRect) -> CGFloat {
        min(Self.maxDocHeight, max(48, bounds.height - 96))
    }

    @objc private func clicked() {
        onClick?()
    }
}

final class HoverDocView: NSTextView {
    override var acceptsFirstResponder: Bool { false }

    convenience init() {
        self.init(frame: .zero, textContainer: nil)
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let text = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        text.lineFragmentPadding = 0
        text.widthTracksTextView = false
        layout.addTextContainer(text)
        storage.addLayoutManager(layout)
        super.init(frame: frameRect, textContainer: text)
        isEditable = false
        isSelectable = false
        isRichText = false
        drawsBackground = false
        isVerticallyResizable = false
        isHorizontallyResizable = false
        autoresizingMask = []
        textContainerInset = .zero
        minSize = .zero
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func fill(_ text: String, color: NSColor) {
        textStorage?.setAttributedString(NSAttributedString(string: text, attributes: [
            .font: Tokens.nsUI(11),
            .foregroundColor: color,
        ]))
    }

    func used(maxWidth: CGFloat) -> NSSize {
        guard let container = textContainer, let layout = layoutManager, maxWidth > 1 else {
            return .zero
        }
        let grow = isVerticallyResizable
        isVerticallyResizable = false
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        container.containerSize = NSSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
        let length = textStorage?.length ?? 0
        if length > 0 {
            layout.invalidateLayout(forCharacterRange: NSRange(location: 0, length: length), actualCharacterRange: nil)
        }
        layout.ensureLayout(for: container)
        let rect = layout.usedRect(for: container)
        isVerticallyResizable = grow
        return NSSize(width: ceil(rect.width), height: ceil(rect.height))
    }
}

final class HoverMouseWatch: NSView {
    var onExit: (() -> Void)?
    private var area: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area {
            removeTrackingArea(area)
        }
        let next = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(next)
        area = next
    }

    override func mouseExited(with event: NSEvent) {
        onExit?()
    }
}
