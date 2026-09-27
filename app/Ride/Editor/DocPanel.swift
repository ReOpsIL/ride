import AppKit

final class DocPanel: PinnablePanel {
    static let defaultSize = NSSize(width: 520, height: 360)
    let panel: NSPanel
    private let chrome = DocChrome(frame: .zero)
    private let web = DocWebView()
    private(set) var html = ""
    private var lastSize = DocPanel.defaultSize
    var onPin: (() -> Void)?
    var onLink: ((String) -> Void)?

    init() {
        panel = PopupPanelKit.makePanel()
        chrome.autoresizingMask = [.width, .height]
        chrome.web = web.view
        chrome.addSubview(web.view)
        chrome.pin.target = self
        chrome.pin.action = #selector(pinClicked)
        web.view.translatesAutoresizingMaskIntoConstraints = true
        web.onLink = { [weak self] target in
            self?.onLink?(target)
        }
        panel.contentView = chrome
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show(title: String, origin: String, html: String, anchor: NSRect, bounds: NSRect) {
        self.html = html
        chrome.title.stringValue = title
        chrome.origin.stringValue = origin
        web.show(html: html)
        if panel.isVisible {
            lastSize = panel.frame.size
            return
        }
        OverlayPanel.present(panel, frame: HoverPanel.place(size: lastSize, anchor: anchor, bounds: bounds))
    }

    func hide() {
        lastSize = panel.frame.size
        panel.orderOut(nil)
        html = ""
        chrome.setPinned(false)
    }

    func setPinned(_ pinned: Bool) {
        chrome.setPinned(pinned)
    }

    @objc private func pinClicked() {
        onPin?()
    }
}

final class DocChrome: NSView {
    let card = OverlayCardView()
    let header = NSView()
    let title = NSTextField(labelWithString: "")
    let origin = NSTextField(labelWithString: "")
    let pin = NSButton()
    var web: NSView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(card)
        header.wantsLayer = true
        title.font = Tokens.nsUI(12, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail
        origin.font = Tokens.nsMono(11)
        origin.lineBreakMode = .byTruncatingMiddle
        PopupPanelKit.configurePin(pin)
        addSubview(header)
        header.addSubview(title)
        header.addSubview(origin)
        header.addSubview(pin)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setPinned(_ pinned: Bool) {
        PopupPanelKit.setPinned(pin, pinned)
    }

    override func layout() {
        super.layout()
        card.frame = bounds
        card.applyTheme()
        let chrome = ThemeStore.shared.chrome
        title.textColor = chrome.textPrimary
        origin.textColor = chrome.textSecondary
        PopupPanelKit.tint(pin)
        let h = Tokens.Size.panelHeader
        header.frame = NSRect(x: 0, y: bounds.height - h, width: bounds.width, height: h)
        pin.frame = NSRect(x: bounds.width - 28, y: 3, width: 22, height: 22)
        let textWidth = max(0, bounds.width - 40)
        title.frame = NSRect(x: Tokens.Space.m, y: 14, width: textWidth, height: 14)
        origin.frame = NSRect(x: Tokens.Space.m, y: 0, width: textWidth, height: 14)
        web?.frame = NSRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - h))
    }
}
