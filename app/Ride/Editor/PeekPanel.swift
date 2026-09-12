import AppKit

final class PeekPanel {
    let panel: NSPanel
    private let chrome = PeekChrome(frame: .zero)
    private let scroll = NSScrollView()
    let text: RideTextView
    private var lastSize = DocPanel.defaultSize
    private(set) var excerpts: [DefinitionExcerpt] = []
    private(set) var index = 0
    private var expanded = false
    var onPin: (() -> Void)?
    var onOpen: (() -> Void)?

    init() {
        text = RideTextView.makeTK2()
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: DocPanel.defaultSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = !DemoLaunch.isDemo
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        panel.isRestorable = false
        panel.minSize = NSSize(width: 280, height: 160)
        chrome.autoresizingMask = [.width, .height]
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = text
        chrome.body = scroll
        chrome.addSubview(scroll)
        chrome.pin.target = self
        chrome.pin.action = #selector(pinClicked)
        chrome.open.target = self
        chrome.open.action = #selector(openClicked)
        chrome.segments.target = self
        chrome.segments.action = #selector(segmentChanged)
        text.isEditable = false
        text.showIndentGuides = false
        text.usesFindBar = false
        panel.contentView = chrome
    }

    var isVisible: Bool {
        panel.isVisible
    }

    var excerptText: String {
        text.string
    }

    func show(excerpts: [DefinitionExcerpt], anchor: NSRect, bounds: NSRect) {
        self.excerpts = excerpts
        index = 0
        expanded = false
        render()
        if panel.isVisible {
            lastSize = panel.frame.size
            return
        }
        OverlayPanel.present(panel, frame: HoverPanel.place(size: lastSize, anchor: anchor, bounds: bounds))
    }

    func hide() {
        lastSize = panel.frame.size
        panel.orderOut(nil)
        excerpts = []
        chrome.setPinned(false)
    }

    func setPinned(_ pinned: Bool) {
        chrome.setPinned(pinned)
    }

    func current() -> DefinitionExcerpt? {
        excerpts.indices.contains(index) ? excerpts[index] : nil
    }

    private func render() {
        guard let excerpt = current() else {
            return
        }
        chrome.origin.stringValue = DocPage.origin(path: excerpt.path, line: excerpt.line)
        chrome.setSegments(
            PeekSegments.labels(excerpts.map(\.label), expanded: expanded),
            selected: PeekSegments.selection(excerpts.map(\.label), expanded: expanded, index: index)
        )
        text.string = excerpt.text
        text.applyTheme(ThemeStore.shared.theme)
        let end = UInt32(excerpt.text.utf8.count)
        HighlightApply.apply(
            SessionUpdate(
                sessionGeneration: 0,
                changed: [ByteRange(startByte: 0, endByte: end)],
                highlights: excerpt.highlights,
                outline: nil,
                errors: []
            ),
            text: excerpt.text,
            view: text
        )
    }

    @objc private func pinClicked() {
        onPin?()
    }

    @objc private func openClicked() {
        onOpen?()
    }

    @objc private func segmentChanged() {
        let next = chrome.segments.selectedSegment
        if PeekSegments.isMore(excerpts.map(\.label), expanded: expanded, index: next) {
            expanded = true
            render()
            return
        }
        guard excerpts.indices.contains(next), next != index else {
            return
        }
        index = next
        render()
    }
}

final class PeekChrome: NSView {
    let card = OverlayCardView()
    let header = NSView()
    let origin = NSTextField(labelWithString: "")
    let open = NSButton(title: "Open", target: nil, action: nil)
    let pin = NSButton()
    let segments = NSSegmentedControl()
    var body: NSView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(card)
        origin.font = Tokens.nsMono(11)
        origin.lineBreakMode = .byTruncatingMiddle
        open.bezelStyle = .roundRect
        open.font = Tokens.nsUI(11)
        open.toolTip = "Open (F12)"
        pin.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin")
        pin.alternateImage = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
        pin.setButtonType(.toggle)
        pin.isBordered = false
        pin.imagePosition = .imageOnly
        pin.toolTip = "Pin"
        segments.segmentStyle = .rounded
        segments.trackingMode = .selectOne
        segments.isHidden = true
        addSubview(header)
        header.addSubview(origin)
        header.addSubview(open)
        header.addSubview(pin)
        header.addSubview(segments)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setPinned(_ pinned: Bool) {
        pin.state = pinned ? .on : .off
        pin.contentTintColor = pinned ? ThemeStore.shared.chrome.accent : ThemeStore.shared.chrome.textSecondary
    }

    func setSegments(_ labels: [String], selected: Int) {
        let show = labels.count > 1
        segments.isHidden = !show
        guard show else {
            needsLayout = true
            return
        }
        segments.segmentCount = labels.count
        for (i, label) in labels.enumerated() {
            segments.setLabel(label.isEmpty ? "\(i + 1)" : label, forSegment: i)
        }
        segments.selectedSegment = selected
        needsLayout = true
    }

    override func layout() {
        super.layout()
        card.frame = bounds
        card.applyTheme()
        let chrome = ThemeStore.shared.chrome
        origin.textColor = chrome.textPrimary
        pin.contentTintColor = pin.state == .on ? chrome.accent : chrome.textSecondary
        let extra: CGFloat = segments.isHidden ? 0 : 24
        let h = Tokens.Size.panelHeader + extra
        header.frame = NSRect(x: 0, y: bounds.height - h, width: bounds.width, height: h)
        pin.frame = NSRect(x: bounds.width - 28, y: extra + 3, width: 22, height: 22)
        open.frame = NSRect(x: bounds.width - 80, y: extra + 3, width: 48, height: 22)
        origin.frame = NSRect(x: Tokens.Space.m, y: extra + 6, width: max(0, bounds.width - 92), height: 16)
        segments.frame = NSRect(x: Tokens.Space.m, y: 2, width: max(0, bounds.width - 16), height: 22)
        body?.frame = NSRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - h))
    }
}
