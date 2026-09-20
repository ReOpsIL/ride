import AppKit

final class RideTextView: NSTextView {
    var tabWidth = 4
    var baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    var appliedFontSize = 0
    var showIndentGuides = true
    var showCodeVision = true
    let lines = LineIndex()

    func lineIndex() -> LineIndex {
        lines.refresh(textStorage?.mutableString ?? "")
        return lines
    }

    override func didChangeText() {
        lines.invalidate()
        super.didChangeText()
    }

    override var typingAttributes: [NSAttributedString.Key: Any] {
        get {
            var attributes = super.typingAttributes
            attributes.removeValue(forKey: .underlineStyle)
            attributes.removeValue(forKey: .underlineColor)
            return attributes
        }
        set {
            super.typingAttributes = newValue
        }
    }
    var hooks = EditorHooks()
    var hoverArea: NSTrackingArea?
    var selectionStack: [NSRange] = []
    var folds = FoldSet()
    let foldDelegate = FoldLayoutDelegate()
    private var currentLineUTF16 = NSRange(location: 0, length: 0)

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        applyDefaults()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        applyDefaults()
    }

    static func makeTK2() -> RideTextView {
        let storage = NSTextContentStorage()
        let layout = NSTextLayoutManager()
        storage.addTextLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 0, height: 1e7))
        layout.textContainer = container
        let view = RideTextView(frame: .zero, textContainer: container)
        view.foldDelegate.view = view
        layout.delegate = view.foldDelegate
        return view
    }

    override func draw(_ dirtyRect: NSRect) {
        IndentGuides.draw(in: self, rect: dirtyRect)
        super.draw(dirtyRect)
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            EditorPanes.shared.focus(view: self)
        }
        return became
    }

    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override func pasteAsRichText(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    func updateCurrentLineHighlight() {
        guard let tlm = textLayoutManager, let storage = textContentStorage else {
            return
        }
        if let prev = nsRangeToTextRange(currentLineUTF16, storage: storage) {
            tlm.removeRenderingAttribute(.backgroundColor, for: prev)
        }
        let line = lineNSRange()
        currentLineUTF16 = line
        if let next = nsRangeToTextRange(line, storage: storage) {
            tlm.addRenderingAttribute(
                .backgroundColor,
                value: ThemeStore.shared.editor.currentLine,
                for: next
            )
        }
        BracketHighlight.restore(self)
    }

    func lineNSRange() -> NSRange {
        let ns = string as NSString
        let loc = min(selectedRange().location, ns.length)
        var start = 0
        var end = 0
        ns.getLineStart(&start, end: &end, contentsEnd: nil, for: NSRange(location: loc, length: 0))
        return NSRange(location: start, length: max(end - start, 0))
    }

    func textRange(utf16 range: NSRange) -> NSTextRange? {
        guard let storage = textContentStorage else {
            return nil
        }
        return nsRangeToTextRange(range, storage: storage)
    }

    func firstVisibleLine() -> Int {
        guard let tlm = textLayoutManager,
              let storage = textContentStorage,
              let vp = tlm.textViewportLayoutController.viewportRange
        else {
            return 1
        }
        let start16 = storage.offset(from: storage.documentRange.location, to: vp.location)
        return lineIndex().line(at: start16)
    }

    func visibleBytes() -> ByteRange? {
        guard let tlm = textLayoutManager,
              let storage = textContentStorage,
              let vp = tlm.textViewportLayoutController.viewportRange
        else {
            return nil
        }
        let start16 = storage.offset(from: storage.documentRange.location, to: vp.location)
        let endLoc = vp.endLocation ?? vp.location
        let end16 = storage.offset(from: storage.documentRange.location, to: endLoc)
        let text = string
        return ByteRange(
            startByte: UInt32(Utf16.utf8Offset(in: text, utf16: start16)),
            endByte: UInt32(Utf16.utf8Offset(in: text, utf16: end16))
        )
    }

    private func nsRangeToTextRange(_ range: NSRange, storage: NSTextContentStorage) -> NSTextRange? {
        let clamped = RangeShift.clamp(range, length: (string as NSString).length)
        guard let start = storage.location(storage.documentRange.location, offsetBy: clamped.location) else {
            return nil
        }
        let end = storage.location(start, offsetBy: clamped.length) ?? start
        return NSTextRange(location: start, end: end)
    }
}
