import AppKit

extension RideTextView {
    func applyCodeVision(_ enabled: Bool) {
        guard showCodeVision != enabled else {
            return
        }
        showCodeVision = enabled
        if showCodeVision, let document = hooks.binding?()?.document {
            UsageCounter.refresh(document: document)
        } else {
            refreshFolds()
        }
    }

    var visionLineHeight: CGFloat {
        VisionLayout.lineHeight(
            ascender: baseFont.ascender,
            descender: baseFont.descender,
            leading: baseFont.leading
        )
    }

    var visionFont: NSFont {
        Tokens.nsMono(max(baseFont.pointSize - 2, 9))
    }

    func visionLines() -> [VisionLine] {
        guard showCodeVision, let document = hooks.binding?()?.document else {
            return []
        }
        let text = string
        let index = lineIndex()
        let items = document.outline.map { row -> VisionItem in
            let utf16 = Utf16.utf16Offset(in: text, utf8: Int(row.startByte))
            return VisionItem(name: row.name, line: index.line(at: utf16))
        }
        return UsageVision.lines(items: items, counts: document.visionCounts)
    }

    func visionLabel(forLine line: Int) -> String? {
        visionLines().first { $0.line == line }?.label
    }

    func visionLine(at paragraph: NSRange) -> VisionLine? {
        let line = lineIndex().line(at: paragraph.location)
        return visionLines().first { $0.line == line }
    }

    func visionIndent(at paragraph: NSRange) -> CGFloat {
        let ns = string as NSString
        let loc = min(paragraph.location, ns.length)
        var start = 0
        var end = 0
        ns.getLineStart(&start, end: &end, contentsEnd: nil, for: NSRange(location: loc, length: 0))
        let line = ns.substring(with: NSRange(location: start, length: max(end - start, 0)))
        let space = " ".size(withAttributes: [.font: baseFont]).width
        return VisionLayout.indentWidth(prefix: line, spaceWidth: space, tabWidth: tabWidth)
    }

    func visionHit(at point: NSPoint) -> Int? {
        guard showCodeVision, let tlm = textLayoutManager, let storage = textContentStorage else {
            return nil
        }
        let origin = textContainerOrigin
        let container = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        guard let fragment = tlm.textLayoutFragment(for: container) as? VisionFragment else {
            return nil
        }
        let local = CGPoint(
            x: container.x - fragment.layoutFragmentFrame.minX,
            y: container.y - fragment.layoutFragmentFrame.minY
        )
        guard fragment.containsLabel(at: local) else {
            return nil
        }
        return storage.offset(from: storage.documentRange.location, to: fragment.rangeInElement.location)
    }

    func placeCaretOnVisionItem(at utf16: Int) {
        let text = string
        let line = lineIndex().line(at: utf16)
        let document = hooks.binding?()?.document
        let row = document?.outline.first { row in
            lineIndex().line(at: Utf16.utf16Offset(in: text, utf8: Int(row.startByte))) == line
        }
        let loc = row.map { Utf16.utf16Offset(in: text, utf8: Int($0.startByte)) } ?? utf16
        setSelectedRange(NSRange(location: min(loc, (text as NSString).length), length: 0))
    }
}
