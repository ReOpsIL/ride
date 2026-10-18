import AppKit

extension RideTextView {
    func overlayPlaced(_ active: [StoredDiagnostic], map: Utf16Map, index: LineIndex) -> [OverlayDrawn] {
        active.map { diagnostic in
            OverlayDrawn(
                layout: OverlayModel.place(
                    diagnostic,
                    lineAt: { index.line(at: $0) },
                    lineStart: { index.range(line: $0)?.location ?? 0 },
                    utf16: { map.utf16(byte: $0) },
                    visibleLine: { self.overlayVisibleLine($0, index: index) },
                    x: { self.overlayPoint(at: $0) },
                    width: { self.overlayWidth($0) }
                ),
                level: diagnostic.level
            )
        }
    }

    func storeOverlay(_ drawn: [OverlayDrawn]) {
        overlayCache.drawn = drawn
        let gutter = overlayGutter(from: drawn)
        overlayCache.numbers = gutter.numbers
        overlayCache.brackets = gutter.brackets
        overlayCache.stamps = overlayStamps(from: drawn)
    }

    private func overlayVisibleLine(_ line: Int, index: LineIndex) -> Int {
        guard let range = index.range(line: line) else {
            return line
        }
        let covering = folds.ranges.filter { $0.location < range.location && NSMaxRange(range) <= NSMaxRange($0) }
        guard let inner = covering.min(by: { $0.length < $1.length }) else {
            return line
        }
        return index.line(at: inner.location)
    }

    private func overlayPoint(at utf16: Int) -> CGFloat {
        let length = (string as NSString).length
        let index = min(max(utf16, 0), length)
        guard let tlm = textLayoutManager,
              let storage = textContentStorage,
              let range = textRange(utf16: NSRange(location: index, length: 0)),
              let fragment = tlm.textLayoutFragment(for: range.location)
        else {
            return 0
        }
        let base = storage.offset(from: storage.documentRange.location, to: fragment.rangeInElement.location)
        let local = max(0, index - base)
        guard let line = fragment.textLineFragments.last(where: { $0.characterRange.location <= local }) ?? fragment.textLineFragments.first else {
            return 0
        }
        return line.typographicBounds.minX + line.locationForCharacter(at: local).x
    }

    private func overlayWidth(_ text: String) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: visionFont]).width + 8
    }

    private func overlayGutter(from drawn: [OverlayDrawn]) -> OverlayGutterToken {
        var numbers: [Int: [OverlayGutterNumber]] = [:]
        var brackets: [OverlayGutterBracket] = []
        for item in drawn {
            let warning = item.level == .warning
            for mark in item.layout.numbers {
                numbers[mark.line, default: []].append(OverlayGutterNumber(mark: mark, warning: warning))
            }
            for bracket in item.layout.brackets {
                brackets.append(OverlayGutterBracket(bracket: bracket, warning: warning))
            }
        }
        return OverlayGutterToken(numbers: numbers, brackets: brackets)
    }

    private func overlayStamps(from drawn: [OverlayDrawn]) -> [Int: String] {
        var stamps: [Int: String] = [:]
        for item in drawn {
            for line in item.layout.rows.keys {
                stamps[line] = overlayStamp(line, drawn: drawn)
            }
            if !item.layout.notes.isEmpty {
                stamps[item.layout.primaryLine] = overlayStamp(item.layout.primaryLine, drawn: drawn)
            }
        }
        return stamps
    }

    private func overlayStamp(_ line: Int, drawn: [OverlayDrawn]) -> String {
        drawn.map { item in
            let chips = item.layout.rows[line]?.flatMap(\.chips).map { "\($0.offset)\($0.text)" }.joined() ?? ""
            let notes = item.layout.primaryLine == line ? item.layout.notes.map { noteStamp($0) }.joined() : ""
            return chips + notes
        }.joined(separator: "|")
    }

    private func noteStamp(_ note: OverlayNoteRow) -> String {
        "\(note.level)\(note.message)\(note.jumpLine ?? 0)\(note.fixTitle ?? "")"
    }
}
