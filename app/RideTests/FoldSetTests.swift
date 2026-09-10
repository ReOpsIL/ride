import XCTest
@testable import Ride

final class FoldSetTests: XCTestCase {
    func testHidesParagraphsStrictlyInsideAndClampsCaret() {
        var folds = FoldSet()
        folds.add(NSRange(location: 10, length: 20))
        XCTAssertTrue(folds.hides(NSRange(location: 12, length: 5)))
        XCTAssertFalse(folds.hides(NSRange(location: 5, length: 10)))
        XCTAssertTrue(folds.startsFold(at: NSRange(location: 5, length: 10)))
        XCTAssertEqual(folds.clampCaret(15), 30)
        XCTAssertEqual(folds.clampCaret(10), 10)
        XCTAssertEqual(folds.clampCaret(40), 40)
    }

    func testEditsShiftOrDropFolds() {
        var folds = FoldSet()
        folds.add(NSRange(location: 10, length: 20))
        folds.add(NSRange(location: 50, length: 10))
        folds.textChanged(range: NSRange(location: 0, length: 0), insertedLength: 3)
        XCTAssertEqual(folds.ranges, [NSRange(location: 13, length: 20), NSRange(location: 53, length: 10)])
        folds.textChanged(range: NSRange(location: 20, length: 1), insertedLength: 0)
        XCTAssertEqual(folds.ranges, [NSRange(location: 52, length: 10)])
        XCTAssertTrue(folds.remove(containing: 55))
        XCTAssertTrue(folds.isEmpty)
    }
}
