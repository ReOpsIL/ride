import AppKit
import WebKit

final class HtmlFindHost: NSScrollView {
    let web: HtmlSurface
    let finder = NSTextFinder()
    var paneID: UUID?
    var onLayout: (() -> Void)?
    private var replaceShown = false
    private var placing = false

    var onFocus: (() -> Void)? {
        get { web.onFocus }
        set { web.onFocus = newValue }
    }

    init(web: HtmlSurface) {
        self.web = web
        super.init(frame: .zero)
        borderType = .noBorder
        drawsBackground = false
        hasVerticalScroller = false
        hasHorizontalScroller = false
        verticalScrollElasticity = .none
        horizontalScrollElasticity = .none
        findBarPosition = .aboveContent
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsets()
        documentView = web
        web.autoresizingMask = [.width, .height]
        bindFinder()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        bindFinder()
    }

    override func layout() {
        if !placing {
            super.layout()
            placeFindBar()
        }
        let frame = NSRect(origin: .zero, size: contentView.bounds.size)
        if web.frame != frame {
            web.frame = frame
        }
        onLayout?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if performFindKey(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    func noteScrolled() {
        finder.findIndicatorNeedsUpdate = true
    }

    func toggleFind(replace: Bool) {
        bindFinder()
        if replace {
            guard !(replaceShown && isFindBarVisible) else {
                hideFind()
                return
            }
            finder.performAction(.showReplaceInterface)
            replaceShown = true
            reveal()
            return
        }
        guard !isFindBarVisible else {
            hideFind()
            return
        }
        finder.performAction(.showFindInterface)
        reveal()
    }

    func find(backwards: Bool) {
        bindFinder()
        finder.performAction(backwards ? .previousMatch : .nextMatch)
    }

    func useSelection() {
        bindFinder()
        finder.performAction(.setSearchString)
    }

    func performFindKey(_ event: NSEvent) -> Bool {
        guard let combo = KeyCombo(event: event) else {
            return false
        }
        switch combo {
        case KeyCombo(glyphs: "⌘F"):
            toggleFind(replace: false)
        case KeyCombo(glyphs: "⌥⌘F"):
            toggleFind(replace: true)
        case KeyCombo(glyphs: "⌘G"):
            find(backwards: false)
        case KeyCombo(glyphs: "⇧⌘G"):
            find(backwards: true)
        case KeyCombo(glyphs: "⌥⌘E"):
            useSelection()
        default:
            return false
        }
        return true
    }

    static func focused(in responder: NSResponder?) -> HtmlFindHost? {
        if let host = host(containing: responder as? NSView) {
            return host
        }
        guard let editor = responder as? NSText, let field = editor.delegate as? NSView else {
            return nil
        }
        return host(containing: field)
    }

    static func host(in window: NSWindow, pane: UUID) -> HtmlFindHost? {
        guard let root = window.contentView else {
            return nil
        }
        return find(in: root, pane: pane)
    }

    private func bindFinder() {
        finder.client = web
        finder.findBarContainer = self
        finder.isIncrementalSearchingEnabled = true
    }

    private func reveal() {
        guard !isFindBarVisible else {
            return
        }
        isFindBarVisible = true
        placeFindBar()
    }

    private func placeFindBar() {
        guard !placing, bounds.height > 1 else {
            return
        }
        let bar = isFindBarVisible ? findBarView : nil
        let height = bar.map { $0.frame.height > 1 ? $0.frame.height : $0.fittingSize.height } ?? 0
        let barFrame = NSRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
        let clip = NSRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - height))
        placing = true
        if let bar, bar.frame != barFrame {
            bar.frame = barFrame
        }
        findBarView?.isHidden = bar == nil
        if contentView.frame != clip {
            contentView.frame = clip
        }
        placing = false
    }

    private func hideFind() {
        finder.performAction(.hideFindInterface)
        if isFindBarVisible {
            isFindBarVisible = false
        }
        placeFindBar()
        replaceShown = false
        window?.makeFirstResponder(web)
    }

    private static func host(containing view: NSView?) -> HtmlFindHost? {
        var current = view
        while let item = current {
            if let host = item as? HtmlFindHost {
                return host
            }
            current = item.superview
        }
        return nil
    }

    private static func find(in view: NSView, pane: UUID) -> HtmlFindHost? {
        if let host = view as? HtmlFindHost, host.paneID == pane {
            return host
        }
        for child in view.subviews {
            if let host = find(in: child, pane: pane) {
                return host
            }
        }
        return nil
    }
}
