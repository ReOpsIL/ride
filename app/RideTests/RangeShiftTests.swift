import XCTest

final class RangeShiftTests: XCTestCase {
    private let underline = NSRange(location: 10, length: 5)

    func testEditBeforeShiftsRange() {
        let edit = NSRange(location: 2, length: 0)
        XCTAssertEqual(RangeShift.shifted(underline, replacing: edit, with: 3), NSRange(location: 13, length: 5))
        let deletion = NSRange(location: 2, length: 4)
        XCTAssertEqual(RangeShift.shifted(underline, replacing: deletion, with: 0), NSRange(location: 6, length: 5))
    }

    func testEditAfterLeavesRange() {
        let edit = NSRange(location: 16, length: 2)
        XCTAssertEqual(RangeShift.shifted(underline, replacing: edit, with: 7), underline)
    }

    func testInsertInsideOrAtEndGrowsRange() {
        let inside = NSRange(location: 12, length: 0)
        XCTAssertEqual(RangeShift.shifted(underline, replacing: inside, with: 2), NSRange(location: 10, length: 7))
        let atEnd = NSRange(location: 15, length: 0)
        XCTAssertEqual(RangeShift.shifted(underline, replacing: atEnd, with: 1), NSRange(location: 10, length: 6))
    }

    func testReplacementCoveringRangeKeepsInsertedText() {
        let covering = NSRange(location: 8, length: 10)
        XCTAssertEqual(RangeShift.shifted(underline, replacing: covering, with: 4), NSRange(location: 8, length: 4))
        XCTAssertNil(RangeShift.shifted(underline, replacing: covering, with: 0))
    }

    func testOverlapUnionsAndShifts() {
        let overlap = NSRange(location: 13, length: 6)
        XCTAssertEqual(RangeShift.shifted(underline, replacing: overlap, with: 1), NSRange(location: 10, length: 4))
    }

    func testClampKeepsRangesInsideText() {
        XCTAssertEqual(RangeShift.clamp(NSRange(location: 10, length: 20), length: 15), NSRange(location: 10, length: 5))
        XCTAssertEqual(RangeShift.clamp(NSRange(location: 20, length: 3), length: 15), NSRange(location: 15, length: 0))
    }
}
