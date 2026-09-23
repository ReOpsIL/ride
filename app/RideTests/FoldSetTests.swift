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

    func testIsFoldStartLine() {
        var folds = FoldSet()
        XCTAssertFalse(folds.isFoldStart(line: 2))
        folds.setStartLines([2, 8, 15])
        XCTAssertTrue(folds.isFoldStart(line: 2))
        XCTAssertTrue(folds.isFoldStart(line: 8))
        XCTAssertFalse(folds.isFoldStart(line: 1))
        XCTAssertFalse(folds.isFoldStart(line: 9))
        folds.add(NSRange(location: 10, length: 20))
        XCTAssertTrue(folds.isFoldStart(line: 8))
        folds.textChanged(range: NSRange(location: 0, length: 0), insertedLength: 1)
        XCTAssertFalse(folds.isFoldStart(line: 8))
        folds.setStartLines([8])
        folds.removeAll()
        XCTAssertFalse(folds.isFoldStart(line: 8))
    }

    func testEditInsideAFoldReleasesItsRegionInNewCoordinates() {
        var set = FoldSet()
        set.add(NSRange(location: 10, length: 20))
        set.add(NSRange(location: 50, length: 5))
        let released = set.textChanged(range: NSRange(location: 15, length: 2), insertedLength: 6)
        XCTAssertEqual(released, [NSRange(location: 10, length: 24)])
        XCTAssertEqual(set.ranges, [NSRange(location: 54, length: 5)])
    }

    func testShiftedFoldsReleaseNothing() {
        var set = FoldSet()
        set.add(NSRange(location: 10, length: 20))
        XCTAssertEqual(set.textChanged(range: NSRange(location: 0, length: 0), insertedLength: 3), [])
    }

    func testChangedListsFoldsOnlyInOneSet() {
        var old = FoldSet()
        old.add(NSRange(location: 0, length: 10))
        old.add(NSRange(location: 20, length: 5))
        var new = old
        new.remove(containing: 22)
        new.add(NSRange(location: 40, length: 3))
        XCTAssertEqual(
            Set(FoldSet.changed(from: old, to: new)),
            [NSRange(location: 20, length: 5), NSRange(location: 40, length: 3)]
        )
    }
}
