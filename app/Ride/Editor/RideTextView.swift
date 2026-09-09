import AppKit

final class RideTextView: NSTextView {
    var tabWidth = 4
    private var currentLineUTF16 = NSRange(location: 0, length: 0)

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        applyDefaults()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        applyDefaults()
    }

    func applyDefaults() {
        applyPrefs(.defaults)
        backgroundColor = NSColor.textBackgroundColor
        insertionPointColor = NSColor.textColor
        isRichText = true
        importsGraphics = false
        allowsImageEditing = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isGrammarCheckingEnabled = false
        smartInsertDeleteEnabled = false
        isContinuousSpellCheckingEnabled = false
        enabledTextCheckingTypes = 0
        usesFindBar = false
        usesInspectorBar = false
        isVerticallyResizable = true
        isHorizontallyResizable = false
        minSize = NSSize(width: 0, height: 0)
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textContainer?.widthTracksTextView = true
        textContainer?.heightTracksTextView = false
        textContainer?.lineFragmentPadding = 5
        autoresizingMask = [.width]
        allowsUndo = true
        isEditable = true
        isSelectable = true
        setAccessibilityLabel("Rust")
    }

    func applyPrefs(_ prefs: Preferences) {
        if tabWidth == prefs.tabWidth, font?.pointSize == CGFloat(prefs.fontSize) {
            return
        }
        tabWidth = prefs.tabWidth
        let font = NSFont.monospacedSystemFont(ofSize: CGFloat(prefs.fontSize), weight: .regular)
        let space = " ".size(withAttributes: [.font: font]).width
        let paragraph = NSMutableParagraphStyle()
        paragraph.defaultTabInterval = space * CGFloat(tabWidth)
        paragraph.tabStops = []
        typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraph,
        ]
        defaultParagraphStyle = paragraph
        self.font = font
    }

    static func makeTK2() -> RideTextView {
        let storage = NSTextContentStorage()
        let layout = NSTextLayoutManager()
        storage.addTextLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 0, height: 1e7))
        layout.textContainer = container
        return RideTextView(frame: .zero, textContainer: container)
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
                value: NSColor.selectedTextBackgroundColor.withAlphaComponent(0.22),
                for: next
            )
        }
    }

    private func lineNSRange() -> NSRange {
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
        guard let start = storage.location(storage.documentRange.location, offsetBy: range.location) else {
            return nil
        }
        let end = storage.location(start, offsetBy: range.length) ?? start
        return NSTextRange(location: start, end: end)
    }
}
