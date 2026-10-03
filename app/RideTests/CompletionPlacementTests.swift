import XCTest

final class CompletionPlacementTests: XCTestCase {
    private let screen = NSRect(x: 0, y: 0, width: 1000, height: 800)
    private let size = NSSize(width: 500, height: 100)

    func testBelowKeepsClearLinesUnderTheCaretLine() {
        let caret = NSRect(x: 100, y: 400, width: 1, height: 16)
        let frame = CompletionPlacement.frame(caret: caret, screen: screen, size: size)
        XCTAssertEqual(frame.maxY, caret.minY - 16 * CompletionPlacement.clearLines)
    }

    func testAboveKeepsClearLinesOverTheCaretLine() {
        let caret = NSRect(x: 100, y: 60, width: 1, height: 16)
        let frame = CompletionPlacement.frame(caret: caret, screen: screen, size: size)
        XCTAssertEqual(frame.minY, caret.maxY + 16 * CompletionPlacement.clearLines)
    }

    func testPopupNeverCoversTheCaretLine() {
        for y in stride(from: CGFloat(0), through: 780, by: 20) {
            let caret = NSRect(x: 100, y: y, width: 1, height: 16)
            let frame = CompletionPlacement.frame(caret: caret, screen: screen, size: size)
            XCTAssertFalse(frame.intersects(caret.insetBy(dx: -1, dy: 0)), "caret at \(y)")
        }
    }

    func testTallPopupShrinksIntoTheRoomierSideWhenNeitherFits() {
        let short = NSRect(x: 0, y: 0, width: 1000, height: 500)
        let tall = NSSize(width: 500, height: 460)
        let caret = NSRect(x: 100, y: 60, width: 1, height: 16)
        let frame = CompletionPlacement.frame(caret: caret, screen: short, size: tall)
        XCTAssertEqual(frame.minY, caret.maxY + 16 * CompletionPlacement.clearLines)
        XCTAssertEqual(frame.maxY, short.maxY)
        XCTAssertTrue(short.contains(frame))
    }
}
