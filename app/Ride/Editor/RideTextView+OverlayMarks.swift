import AppKit

extension RideTextView {
    func shiftOverlayPaint(replacing edit: NSRange, with length: Int) {
        overlayCache.painted = RangeShift.shifted(overlayCache.painted, replacing: edit, with: length)
    }

    func overlayMarkRanges() -> [NSRange] {
        overlayCache.painted
    }

    func overlayMarks(length: Int) -> [UnderlineMark] {
        guard overlayMode != .off else {
            return []
        }
        return overlayCache.spanMarks.compactMap { overlayMark($0, length: length) }
    }

    func assignOverlayMarks(_ active: [StoredDiagnostic], map: Utf16Map, length: Int) {
        overlayCache.spanMarks = active.flatMap { overlaySpanMarks($0, map: map, length: length) }
    }

    private func overlaySpanMarks(_ diagnostic: StoredDiagnostic, map: Utf16Map, length: Int) -> [OverlaySpanMark] {
        var labels: [(StoredLabel, Bool)] = diagnostic.secondary.filter { $0.path == diagnostic.path }.map { ($0, false) }
        for note in diagnostic.notes {
            labels += note.labels.filter { $0.path == diagnostic.path }.map { ($0, true) }
        }
        return labels.compactMap { label, note in
            DiagnosticRange.nsRange(map: map, length: length, byteStart: label.byteStart, byteEnd: label.byteEnd)
                .map { OverlaySpanMark(range: $0, note: note) }
        }
    }

    private func overlayMark(_ mark: OverlaySpanMark, length: Int) -> UnderlineMark? {
        let range = RangeShift.clamp(mark.range, length: length)
        guard range.length > 0 else {
            return nil
        }
        if mark.note {
            return UnderlineMark(range: range, style: Underlines.noteStyle, color: ThemeStore.shared.chrome.textTertiary)
        }
        return UnderlineMark(range: range, style: Underlines.secondaryStyle, color: ThemeStore.shared.chrome.accent)
    }
}
