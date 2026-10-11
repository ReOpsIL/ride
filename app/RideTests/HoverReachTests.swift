import XCTest

final class HoverReachTests: XCTestCase {
    private let anchor = CGRect(x: 100, y: 200, width: 40, height: 14)
    private let card = CGRect(x: 100, y: 218, width: 300, height: 160)

    func testGapBetweenWordAndCardStaysInside() {
        XCTAssertTrue(HoverReach.contains(mouse: CGPoint(x: 110, y: 216), anchor: anchor, card: card))
    }

    func testPointerOnTheCardStaysInside() {
        XCTAssertTrue(HoverReach.contains(mouse: CGPoint(x: 240, y: 300), anchor: anchor, card: card))
    }

    func testPointerOffToTheSideLeaves() {
        XCTAssertFalse(HoverReach.contains(mouse: CGPoint(x: 40, y: 210), anchor: anchor, card: card))
        XCTAssertFalse(HoverReach.contains(mouse: CGPoint(x: 110, y: 150), anchor: anchor, card: card))
    }

    func testEmptyCardDoesNotCoverTheScreen() {
        XCTAssertFalse(HoverReach.contains(mouse: CGPoint(x: 10, y: 10), anchor: anchor, card: .zero))
        XCTAssertFalse(HoverReach.contains(mouse: CGPoint(x: 120, y: 206), anchor: .zero, card: card))
    }
}
