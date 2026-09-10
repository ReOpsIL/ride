import AppKit

final class CheatSheetPreview: NSView {
    static let width: CGFloat = 360
    private let separator = NSView()
    private let scroll = NSScrollView()
    private let text = NSTextView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        separator.wantsLayer = true
        text.isEditable = false
        text.isSelectable = false
        text.drawsBackground = false
        text.textContainerInset = NSSize(width: Tokens.Space.m, height: Tokens.Space.l)
        text.minSize = .zero
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.containerSize = NSSize(width: Self.width, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.widthTracksTextView = true
        text.textContainer?.lineFragmentPadding = Tokens.Space.xs
        scroll.documentView = text
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        addSubview(separator)
        addSubview(scroll)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        place()
    }

    private func place() {
        separator.frame = NSRect(x: 0, y: 0, width: Tokens.Size.hairline, height: bounds.height)
        scroll.frame = NSRect(x: Tokens.Size.hairline, y: 0, width: bounds.width - Tokens.Size.hairline, height: bounds.height)
        text.frame.size.width = scroll.contentSize.width
    }

    func fill(_ entry: CheatItem?) {
        let chrome = ThemeStore.shared.chrome
        separator.layer?.backgroundColor = chrome.border.cgColor
        text.textStorage?.setAttributedString(Self.content(entry, chrome: chrome))
        text.frame.size.width = scroll.contentSize.width
        text.sizeToFit()
        scroll.contentView.scroll(to: .zero)
    }

    static func content(_ entry: CheatItem?, chrome: ChromeColors) -> NSAttributedString {
        guard let entry else {
            return NSAttributedString(string: "No template", attributes: [.font: Tokens.nsUI(11), .foregroundColor: chrome.textSecondary])
        }
        let out = NSMutableAttributedString()
        out.append(NSAttributedString(string: entry.name + "\n", attributes: [.font: Tokens.nsUI(11, weight: .semibold), .foregroundColor: chrome.textPrimary]))
        out.append(NSAttributedString(string: entry.doc + "\n\n", attributes: [.font: Tokens.nsUI(11), .foregroundColor: chrome.textSecondary]))
        out.append(highlighted(entry.snippet, chrome: chrome))
        out.append(NSAttributedString(string: "\n\n↩ or click again to insert", attributes: [.font: Tokens.nsUI(10), .foregroundColor: chrome.textTertiary]))
        return out
    }

    static func highlighted(_ snippet: String, chrome: ChromeColors) -> NSAttributedString {
        let parsed = SnippetParser.parse(snippet)
        let out = NSMutableAttributedString(
            string: parsed.text,
            attributes: [.font: Tokens.nsMono(11), .foregroundColor: chrome.textPrimary]
        )
        for stop in parsed.stops where stop.range.length > 0 {
            out.addAttributes([
                .foregroundColor: chrome.accent,
                .backgroundColor: chrome.accent.withAlphaComponent(0.14),
            ], range: stop.range)
        }
        return out
    }
}
