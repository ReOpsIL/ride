import XCTest

final class PeekSegmentsTests: XCTestCase {
    private func labels(_ n: Int) -> [String] {
        (0..<n).map { "impl \($0)" }
    }

    func testShortListIsUnchanged() {
        let all = labels(3)
        XCTAssertEqual(PeekSegments.labels(all, expanded: false), all)
    }

    func testLongListCapsAtEightWithMore() {
        let shown = PeekSegments.labels(labels(12), expanded: false)
        XCTAssertEqual(shown.count, 9)
        XCTAssertEqual(shown.last, "+4")
        XCTAssertEqual(shown.first, "impl 0")
    }

    func testExpandedShowsEverything() {
        XCTAssertEqual(PeekSegments.labels(labels(12), expanded: true).count, 12)
        XCTAssertFalse(PeekSegments.isMore(labels(12), expanded: true, index: 8))
    }

    func testMoreIsTheLastCappedSegment() {
        XCTAssertTrue(PeekSegments.isMore(labels(12), expanded: false, index: 8))
        XCTAssertFalse(PeekSegments.isMore(labels(12), expanded: false, index: 7))
        XCTAssertFalse(PeekSegments.isMore(labels(8), expanded: false, index: 7))
    }

    func testSelectionClampsWhenCollapsed() {
        XCTAssertEqual(PeekSegments.selection(labels(12), expanded: false, index: 10), 0)
        XCTAssertEqual(PeekSegments.selection(labels(12), expanded: false, index: 3), 3)
    }
}
