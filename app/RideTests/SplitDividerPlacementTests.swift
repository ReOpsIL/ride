import XCTest

final class SplitDividerPlacementTests: XCTestCase {
    func testLeadingPaneMovesItsTrailingDivider() {
        let placement = SplitDividerPlacement.divider(for: 0, extents: [200, 800], divider: 1, total: 1001, size: 230, fromEnd: false)
        XCTAssertEqual(placement, SplitDividerPlacement(index: 0, position: 230))
    }

    func testLastPaneFromEndMovesTheDividerAboveIt() {
        let placement = SplitDividerPlacement.divider(for: 1, extents: [700, 300], divider: 1, total: 1001, size: 200, fromEnd: true)
        XCTAssertEqual(placement, SplitDividerPlacement(index: 0, position: 800))
    }

    func testMiddlePaneFromEndLeavesTheLastPaneAlone() {
        let placement = SplitDividerPlacement.divider(for: 1, extents: [500, 150, 200], divider: 1, total: 852, size: 180, fromEnd: true)
        XCTAssertEqual(placement, SplitDividerPlacement(index: 0, position: 470))
    }

    func testFirstPaneCannotBePlacedFromTheEnd() {
        XCTAssertNil(SplitDividerPlacement.divider(for: 0, extents: [500, 200], divider: 1, total: 701, size: 180, fromEnd: true))
    }

    func testUnknownPaneIsIgnored() {
        XCTAssertNil(SplitDividerPlacement.divider(for: 3, extents: [500, 200], divider: 1, total: 701, size: 180, fromEnd: true))
    }
}
