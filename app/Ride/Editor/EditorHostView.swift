import AppKit

final class EditorHostView: NSView {
    let gutter = GutterView()
    let scroll = NSScrollView()
    let textView: RideTextView
    var paneID = UUID()
    private(set) weak var document: BufferDocument?
    var onViewport: (() -> Void)?
    var docsStorage: DocController?
    var peekStorage: PeekController?
    private var gutterWidth: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        textView = RideTextView.makeTK2()
        super.init(frame: frameRect)
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = ThemeStore.shared.editor.background
        scroll.documentView = textView
        scroll.contentView.postsBoundsChangedNotifications = true
        gutter.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gutter)
        addSubview(scroll)
        gutterWidth = gutter.widthAnchor.constraint(equalToConstant: GutterView.width(digits: 3, numbers: true))
        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: leadingAnchor),
            gutter.topAnchor.constraint(equalTo: topAnchor),
            gutter.bottomAnchor.constraint(equalTo: bottomAnchor),
            gutterWidth,
            scroll.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        gutter.attach(textView: textView)
        onViewport = nil
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viewportMoved),
            name: NSView.boundsDidChangeNotification,
            object: scroll.contentView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncGutter),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:)")
    }

    func bind(_ document: BufferDocument) {
        self.document = document
        document.bind(textView)
    }

    func capture() {
        document?.capture(textView)
    }

    func applyPrefs(_ prefs: Preferences) {
        textView.applyPrefs(prefs)
        if gutter.showsNumbers != prefs.lineNumbers {
            gutter.showsNumbers = prefs.lineNumbers
            syncGutter()
        }
    }

    func applyTheme(_ theme: Theme) {
        scroll.backgroundColor = theme.editor.background
        gutter.needsDisplay = true
    }

    @objc func syncGutter() {
        let lines = max(1, textView.lineIndex().lineCount)
        gutterWidth.constant = GutterView.width(digits: String(lines).count, numbers: gutter.showsNumbers)
        gutter.needsDisplay = true
    }

    @objc func viewportMoved() {
        gutter.needsDisplay = true
        onViewport?()
    }
}
