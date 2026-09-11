import XCTest
@testable import Ride

final class SplitLayoutTests: XCTestCase {
    func testToggleOpensHorizontalThenReturnsToSingle() {
        var layout = SplitLayout()
        XCTAssertEqual(layout.split, .single)
        XCTAssertFalse(layout.isSplit)
        XCTAssertEqual(layout.focused, .left)
        layout.toggle()
        XCTAssertEqual(layout.split, .horizontal(ratio: SplitLayout.defaultRatio))
        XCTAssertTrue(layout.isSplit)
        XCTAssertEqual(layout.focused, .right)
        layout.toggle()
        XCTAssertEqual(layout.split, .single)
        XCTAssertEqual(layout.focused, .left)
        XCTAssertFalse(layout.isSplit)
    }

    func testCloseRightPaneFocusesLeft() {
        var layout = SplitLayout()
        layout.toggle()
        layout.focus(.right)
        XCTAssertEqual(layout.focused, .right)
        layout.closeRight()
        XCTAssertEqual(layout.split, .single)
        XCTAssertEqual(layout.focused, .left)
        layout.closeRight()
        XCTAssertEqual(layout.split, .single)
        XCTAssertEqual(layout.focused, .left)
    }

    func testRestoreUsesFocusedSideAndRatio() {
        let right = SplitLayout.restore(SplitState(focused: 1, ratio: 0.4))
        XCTAssertEqual(right.split, .horizontal(ratio: 0.4))
        XCTAssertEqual(right.focused, .right)
        let left = SplitLayout.restore(SplitState(ratio: 0.5))
        XCTAssertEqual(left.split, .horizontal(ratio: 0.5))
        XCTAssertEqual(left.focused, .left)
        XCTAssertEqual(SplitLayout.restore(nil).split, .single)
    }

    func testRatioClamped() {
        var layout = SplitLayout(split: .horizontal(ratio: 0.05))
        XCTAssertEqual(layout.split, .horizontal(ratio: SplitLayout.minRatio))
        layout.setRatio(0.95)
        XCTAssertEqual(layout.split, .horizontal(ratio: SplitLayout.maxRatio))
        layout.setRatio(0.4)
        XCTAssertEqual(layout.split, .horizontal(ratio: 0.4))
        layout.closeRight()
        layout.setRatio(0.3)
        XCTAssertEqual(layout.split, .single)
    }
}
