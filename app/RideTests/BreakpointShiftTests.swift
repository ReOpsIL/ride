import XCTest

final class BreakpointShiftTests: XCTestCase {
    private let text = "l1\nl2\nl3\nl4\nl5\nl6\n"
    private let path = "/a/main.rs"

    private func marks(_ lines: [UInt32]) -> Breakpoints {
        var set = Breakpoints()
        for line in lines {
            set.toggle(path: path, line: line)
        }
        return set
    }

    private func edit(_ range: NSRange, _ inserted: String) -> LineEdit {
        BreakpointShift.lineEdit(before: text, range: range, inserted: inserted)
    }

    private func shifted(_ lines: [UInt32], _ range: NSRange, _ inserted: String) -> (Bool, Set<UInt32>) {
        var set = marks(lines)
        let changed = set.shift(path: path, edit: edit(range, inserted))
        return (changed, set.lines(path: path))
    }

    func testInsertedLineAboveShiftsDown() {
        let (changed, lines) = shifted([2, 4], NSRange(location: 3, length: 0), "\n")
        XCTAssertTrue(changed)
        XCTAssertEqual(lines, [3, 5])
    }

    func testDeletedWholeLinesAboveShiftUp() {
        let (changed, lines) = shifted([5], NSRange(location: 3, length: 6), "")
        XCTAssertTrue(changed)
        XCTAssertEqual(lines, [3])
    }

    func testMarkOnTheLineRightAfterDeletedLinesMovesUp() {
        let (changed, lines) = shifted([4, 6], NSRange(location: 3, length: 6), "")
        XCTAssertTrue(changed)
        XCTAssertEqual(lines, [2, 4])
    }

    func testDeletedLinesDropTheirMarks() {
        let (_, lines) = shifted([2, 3, 5], NSRange(location: 3, length: 6), "")
        XCTAssertEqual(lines, [3])
    }

    func testMidLineDeletionAcrossLinesKeepsFirstAndDropsInside() {
        let (_, lines) = shifted([2, 3, 4, 5], NSRange(location: 4, length: 6), "")
        XCTAssertEqual(lines, [2, 3])
    }

    func testEditOnOwnLineKeepsMark() {
        let (changed, lines) = shifted([4], NSRange(location: 10, length: 0), "X")
        XCTAssertFalse(changed)
        XCTAssertEqual(lines, [4])
    }

    func testSameLineReplacementChangesNothing() {
        let (changed, lines) = shifted([4, 6], NSRange(location: 9, length: 2), "zz")
        XCTAssertFalse(changed)
        XCTAssertEqual(lines, [4, 6])
    }

    func testInsertWithoutNewlineAtLineStartKeepsMark() {
        let (changed, lines) = shifted([4], NSRange(location: 9, length: 0), "x")
        XCTAssertFalse(changed)
        XCTAssertEqual(lines, [4])
    }

    func testReplaceLineWithTwoLinesShiftsFollowing() {
        let (_, lines) = shifted([4, 5], NSRange(location: 9, length: 3), "a\nb\n")
        XCTAssertEqual(lines, [6])
    }

    func testShiftKeepsConditionAndOrder() {
        var set = marks([4, 6])
        set.edit(path: path, line: 6, condition: "i > 2", hitCondition: nil)
        XCTAssertTrue(set.shift(path: path, edit: edit(NSRange(location: 3, length: 0), "\n\n")))
        XCTAssertEqual(set.marks(path: path).map(\.line), [6, 8])
        XCTAssertEqual(set.mark(path: path, line: 8)?.condition, "i > 2")
    }
}
