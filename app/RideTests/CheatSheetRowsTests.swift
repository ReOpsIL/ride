import XCTest
@testable import Ride

final class CheatSheetRowsTests: XCTestCase {
    private func entry(_ name: String) -> CheatItem {
        CheatItem(name: name, doc: "doc", snippet: "\(name) $0")
    }

    private var sections: [CheatGroup] {
        [
            CheatGroup(title: "Control", matched: true, items: [entry("if"), entry("for")]),
            CheatGroup(title: "Items", matched: false, items: [entry("fn")]),
        ]
    }

    func testRowsFlattenWithHeaders() {
        let rows = CheatSheetRows.rows(sections)
        XCTAssertEqual(rows.count, 5)
        XCTAssertEqual(rows[0], .header(title: "Control", matched: true))
        XCTAssertEqual(rows[1].entry?.name, "if")
        XCTAssertEqual(rows[3], .header(title: "Items", matched: false))
        XCTAssertEqual(CheatSheetRows.firstEntry(rows), 1)
    }

    func testStepSkipsHeadersAndClamps() {
        let rows = CheatSheetRows.rows(sections)
        XCTAssertEqual(CheatSheetRows.step(rows, from: 1, by: 1), 2)
        XCTAssertEqual(CheatSheetRows.step(rows, from: 2, by: 1), 4)
        XCTAssertEqual(CheatSheetRows.step(rows, from: 4, by: 1), 4)
        XCTAssertEqual(CheatSheetRows.step(rows, from: 4, by: -1), 2)
        XCTAssertEqual(CheatSheetRows.step(rows, from: 1, by: -1), 1)
    }

    func testSelectionKeepsNameOrFallsBackToFirstEntry() {
        let rows = CheatSheetRows.rows(sections)
        XCTAssertEqual(CheatSheetRows.selection(rows, keeping: "fn"), 4)
        XCTAssertEqual(CheatSheetRows.selection(rows, keeping: "missing"), 1)
        XCTAssertNil(CheatSheetRows.selection([], keeping: nil))
    }

    func testPlacementStacksOnTheFarSideOfTheCompletionPopup() {
        let screen = NSRect(x: 0, y: 0, width: 1000, height: 800)
        let size = NSSize(width: 500, height: 100)
        let caret = NSRect(x: 100, y: 400, width: 1, height: 16)
        let below = NSRect(x: 92, y: 200, width: 520, height: 198)
        let stacked = CheatSheetPlacement.frame(
            size: size,
            anchor: .init(completion: below, completionAboveCaret: false, caret: caret, screen: screen)
        )
        XCTAssertEqual(stacked.maxY, below.minY - CheatSheetPlacement.gap)
        XCTAssertEqual(stacked.minX, below.minX)
        let above = NSRect(x: 92, y: 420, width: 520, height: 198)
        let over = CheatSheetPlacement.frame(
            size: size,
            anchor: .init(completion: above, completionAboveCaret: true, caret: caret, screen: screen)
        )
        XCTAssertEqual(over.minY, above.maxY + CheatSheetPlacement.gap)
    }

    func testPlacementFlipsWhenOffScreen() {
        let screen = NSRect(x: 0, y: 0, width: 1000, height: 800)
        let size = NSSize(width: 500, height: 100)
        let caret = NSRect(x: 100, y: 60, width: 1, height: 16)
        let low = NSRect(x: 92, y: 10, width: 520, height: 40)
        let frame = CheatSheetPlacement.frame(
            size: size,
            anchor: .init(completion: low, completionAboveCaret: false, caret: caret, screen: screen)
        )
        XCTAssertEqual(frame.minY, low.maxY + CheatSheetPlacement.gap)
        let alone = CheatSheetPlacement.frame(
            size: size,
            anchor: .init(completion: nil, completionAboveCaret: false, caret: caret, screen: screen)
        )
        XCTAssertEqual(alone.minY, caret.maxY + 2)
    }
}
