import AppKit

final class GitDiffTextView: NSTextView {
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:)")
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        let rect = bounds.intersection(dirtyRect)
        guard !rect.isEmpty, let layoutManager, let textContainer, let storage = textStorage, storage.length > 0 else {
            return
        }
        let glyphs = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)
        let chars = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        let origin = textContainerOrigin
        storage.enumerateAttribute(.gitDiffTint, in: chars) { value, range, _ in
            guard let color = value as? NSColor else {
                return
            }
            let tinted = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            layoutManager.enumerateLineFragments(forGlyphRange: tinted) { fragment, _, _, _, _ in
                color.setFill()
                NSRect(x: rect.minX, y: fragment.minY + origin.y, width: rect.width, height: fragment.height)
                    .fill(using: .sourceOver)
            }
        }
    }
}
