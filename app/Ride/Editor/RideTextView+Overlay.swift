import AppKit

extension RideTextView {
    func overlayRows(at paragraph: NSRange) -> OverlayRows? {
        let line = lineIndex().line(at: paragraph.location)
        var slices: [OverlaySlice] = []
        for item in overlayCache.drawn {
            let rows = item.layout.rows[line] ?? []
            let notes = item.layout.primaryLine == line ? item.layout.notes : []
            if rows.isEmpty, notes.isEmpty {
                continue
            }
            slices.append(OverlaySlice(rows: rows, notes: notes, level: item.level))
        }
        guard !slices.isEmpty else {
            return nil
        }
        return OverlayRows(slices: slices, lineHeight: visionLineHeight, font: visionFont)
    }

    func refreshOverlay() {
        guard let document = hooks.binding?()?.document else {
            clearOverlayDrawn()
            return
        }
        if overlayMode == .off || document.overlay.fresh.isEmpty {
            guard overlayCache.showsOverlay else {
                return
            }
        }
        Underlines.apply(document: document, view: self, parseErrors: nil)
    }

    func relayoutOverlay() {
        let stamps = overlayStamps()
        let gutter = overlayGutterToken()
        prepareOverlay()
        applyOverlayLayout(from: stamps, gutter: gutter)
    }

    func prepareOverlay() {
        guard let document = hooks.binding?()?.document else {
            clearOverlayDrawn()
            return
        }
        let fresh = document.overlay.fresh
        guard overlayMode != .off, !fresh.isEmpty else {
            clearOverlayDrawn()
            return
        }
        let length = (string as NSString).length
        let map = overlayUtf16Map()
        let index = lineIndex()
        let active = overlayActive(fresh, map: map, length: length, index: index)
        assignOverlayMarks(active, map: map, length: length)
        storeOverlay(overlayPlaced(active, map: map, index: index))
    }

    func overlayStamps() -> [Int: String] {
        overlayCache.stamps
    }

    func overlayGutterToken() -> OverlayGutterToken {
        OverlayGutterToken(numbers: overlayCache.numbers, brackets: overlayCache.brackets)
    }

    func applyOverlayLayout(from stamps: [Int: String], gutter: OverlayGutterToken) {
        let changed = Set(stamps.keys).union(overlayCache.stamps.keys).filter { stamps[$0] != overlayCache.stamps[$0] }
        refreshFragments(in: changed.compactMap(lineRange))
        if gutter != overlayGutterToken() {
            (enclosingScrollView?.superview as? EditorHostView)?.gutter.needsDisplay = true
        }
    }

    func overlayNumbers(on line: Int) -> [OverlayGutterNumber] {
        overlayCache.numbers[line] ?? []
    }

    func overlayBrackets(on line: Int) -> [OverlayGutterBracket] {
        overlayCache.brackets.filter { line >= $0.bracket.start && line <= $0.bracket.end }
    }

    func notePaintedOverlay(length: Int) {
        overlayCache.painted = overlayMarks(length: length).map(\.range)
    }

    private func overlayUtf16Map() -> Utf16Map {
        if overlayCache.utf16Generation != textGeneration {
            overlayCache.utf16 = Utf16Map(string)
            overlayCache.utf16Generation = textGeneration
        }
        return overlayCache.utf16
    }

    private func clearOverlayDrawn() {
        overlayCache.drawn = []
        overlayCache.stamps = [:]
        overlayCache.numbers = [:]
        overlayCache.brackets = []
        overlayCache.spanMarks = []
    }

    private func overlayActive(_ fresh: [StoredDiagnostic], map: Utf16Map, length: Int, index: LineIndex) -> [StoredDiagnostic] {
        OverlaySelection.active(
            caret: selectedRange().location,
            mode: overlayMode,
            diagnostics: fresh,
            lineAt: { index.line(at: $0) },
            range: { self.overlayRange($0, map: map, length: length) }
        )
    }

    private func overlayRange(_ label: StoredLabel, map: Utf16Map, length: Int) -> NSRange {
        let start = map.utf16(byte: Int(label.byteStart))
        let end = map.utf16(byte: Int(label.byteEnd))
        return RangeShift.clamp(NSRange(location: start, length: max(0, end - start)), length: length)
    }
}
