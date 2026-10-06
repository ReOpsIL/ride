import AppKit

final class GitDiffGutter: NSRulerView {
    static let padding: CGFloat = 8

    var document: GitDiffDocument? {
        didSet {
            ruleThickness = thickness
            needsDisplay = true
        }
    }

    var font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular) {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
        clipsToBounds = true
        ruleThickness = thickness
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:)")
    }

    private var columnWidth: CGFloat {
        let digit = ("0" as NSString).size(withAttributes: [.font: font]).width
        return digit * CGFloat(document?.digits ?? 3) + Self.padding
    }

    private var thickness: CGFloat {
        columnWidth * 2 + Self.padding
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        let theme = ThemeStore.shared.theme
        let dirty = bounds.intersection(rect)
        theme.editor.background.setFill()
        dirty.fill()
        theme.chrome.border.setFill()
        NSRect(x: bounds.maxX - 1, y: dirty.minY, width: 1, height: dirty.height).fill()
        guard let document, let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager, let container = textView.textContainer
        else {
            return
        }
        let visible = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: container)
        let chars = layoutManager.characterRange(forGlyphRange: visible, actualGlyphRange: nil)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: theme.editor.gutterText]
        var index = document.line(atCharacter: chars.location)
        while index < document.lineStarts.count, document.lineStarts[index] <= NSMaxRange(chars) {
            let glyph = layoutManager.glyphIndexForCharacter(at: document.lineStarts[index])
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let top = convert(NSPoint(x: 0, y: fragment.minY + textView.textContainerOrigin.y), from: textView).y
            let numbers = document.numbers[index]
            draw(numbers.old, column: 0, top: top, height: fragment.height, attributes: attributes)
            draw(numbers.new, column: 1, top: top, height: fragment.height, attributes: attributes)
            index += 1
        }
    }

    private func draw(_ number: UInt32?, column: CGFloat, top: CGFloat, height: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        guard let number else {
            return
        }
        let label = String(number) as NSString
        let size = label.size(withAttributes: attributes)
        let right = columnWidth * (column + 1)
        label.draw(at: NSPoint(x: right - size.width, y: top + (height - size.height) / 2), withAttributes: attributes)
    }
}
