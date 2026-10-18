import XCTest

final class DiagnosticOverlayTests: XCTestCase {
    func testOffAndAll() {
        let items = [sample(0, 4, .error), sample(20, 30, .warning)]
        XCTAssertTrue(OverlaySelection.active(caret: 1, mode: .off, diagnostics: items, lineAt: line, range: span).isEmpty)
        XCTAssertEqual(OverlaySelection.active(caret: 1, mode: .all, diagnostics: items, lineAt: line, range: span), items)
    }

    func testCaretUsesTheSpanOrThePrimaryLine() {
        let item = sample(10, 14, .error, secondary: [(40, 44, "moved")])
        XCTAssertEqual(OverlaySelection.active(caret: 12, mode: .caret, diagnostics: [item], lineAt: line, range: span), [item])
        XCTAssertEqual(OverlaySelection.active(caret: 0, mode: .caret, diagnostics: [item], lineAt: line, range: span), [item])
        XCTAssertEqual(OverlaySelection.active(caret: 41, mode: .caret, diagnostics: [item], lineAt: line, range: span), [item])
        XCTAssertTrue(OverlaySelection.active(caret: 80, mode: .caret, diagnostics: [item], lineAt: line, range: span).isEmpty)
    }

    func testErrorBeatsWarningThenNarrowerPrimaryWins() {
        let wide = sample(0, 20, .error)
        let narrow = sample(4, 6, .error)
        let warning = sample(0, 1, .warning)
        let ranked = OverlaySelection.active(caret: 0, mode: .caret, diagnostics: [warning, wide, narrow], lineAt: line, range: span)
        XCTAssertEqual(ranked, [narrow])
    }

    func testEditOutsideShiftsEveryOwnedLabel() {
        let item = owned()
        let moved = OverlayShift.shifted(item, replacing: NSRange(location: 0, length: 0), with: 4)
        XCTAssertEqual(moved?.primary.byteStart, item.primary.byteStart + 4)
        XCTAssertEqual(moved?.secondary[0].byteStart, item.secondary[0].byteStart + 4)
        XCTAssertEqual(moved?.notes[0].labels[0].byteStart, item.notes[0].labels[0].byteStart + 4)
        XCTAssertEqual(moved?.secondary[1].byteStart, item.secondary[1].byteStart)
        let after = OverlayShift.shifted(item, replacing: NSRange(location: 500, length: 2), with: 0)
        XCTAssertEqual(after?.primary.byteStart, item.primary.byteStart)
    }

    func testEditInsideALabelIsStale() {
        let item = owned()
        let inside = NSRange(location: Int(item.primary.byteStart), length: 1)
        XCTAssertNil(OverlayShift.shifted(item, replacing: inside, with: 1))
        let note = NSRange(location: Int(item.notes[0].labels[0].byteStart) + 1, length: 0)
        XCTAssertNil(OverlayShift.shifted(item, replacing: note, with: 1))
    }

    private func line(_ utf16: Int) -> Int {
        utf16 < 30 ? 1 : 2
    }

    private func span(_ label: StoredLabel) -> NSRange {
        NSRange(location: Int(label.byteStart), length: Int(label.byteEnd) - Int(label.byteStart))
    }

    private func sample(_ start: Int, _ end: Int, _ level: ProblemLevel, secondary: [(Int, Int, String)] = []) -> StoredDiagnostic {
        StoredDiagnostic(
            primary: label("main.rs", start, end, "primary"),
            level: level,
            message: "m",
            code: "E",
            secondary: secondary.map { label("main.rs", $0.0, $0.1, $0.2) }
        )
    }

    private func owned() -> StoredDiagnostic {
        var item = sample(10, 14, .error, secondary: [(2, 4, "before"), (0, 1, "else")])
        item.secondary[1].path = "/lib/other.rs"
        item.notes = [StoredNote(level: .note, message: "see", labels: [label("main.rs", 20, 24, "there")])]
        return item
    }

    private func label(_ path: String, _ start: Int, _ end: Int, _ text: String) -> StoredLabel {
        StoredLabel(
            path: path,
            byteStart: UInt32(start),
            byteEnd: UInt32(end),
            lineStart: 1,
            lineEnd: 1,
            column: 1,
            text: text,
            macroName: nil
        )
    }
}
