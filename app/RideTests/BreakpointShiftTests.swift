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

    func testInsertedLineAboveShiftsDown() {
        let insertion = edit(NSRange(location: 3, length: 0), "\n")
        XCTAssertEqual(insertion, LineEdit(firstLine: 2, lastLine: 2, newLastLine: 3))
        var set = marks([4])
        XCTAssertTrue(set.shift(path: path, edit: insertion))
        XCTAssertEqual(set.lines(path: path), [5])
    }

    func testDeletedLinesAboveShiftUp() {
        let removal = edit(NSRange(location: 3, length: 6), "")
        XCTAssertEqual(removal, LineEdit(firstLine: 2, lastLine: 4, newLastLine: 2))
        var set = marks([5])
        XCTAssertTrue(set.shift(path: path, edit: removal))
        XCTAssertEqual(set.lines(path: path), [3])
    }

    func testEditOnOwnLineKeepsMark() {
        var set = marks([4])
        XCTAssertFalse(set.shift(path: path, edit: edit(NSRange(location: 10, length: 0), "X")))
        XCTAssertEqual(set.lines(path: path), [4])
    }

    func testDeletedLinesDropMarks() {
        var set = marks([2, 3, 5])
        XCTAssertTrue(set.shift(path: path, edit: edit(NSRange(location: 3, length: 6), "")))
        XCTAssertEqual(set.lines(path: path), [2, 3])
    }

    func testSameLineReplacementChangesNothing() {
        var set = marks([4, 6])
        XCTAssertFalse(set.shift(path: path, edit: edit(NSRange(location: 9, length: 2), "zz")))
        XCTAssertEqual(set.lines(path: path), [4, 6])
    }

    func testShiftKeepsConditionAndOrder() {
        var set = marks([4, 6])
        set.edit(path: path, line: 6, condition: "i > 2", hitCondition: nil)
        XCTAssertTrue(set.shift(path: path, edit: edit(NSRange(location: 3, length: 0), "\n\n")))
        XCTAssertEqual(set.marks(path: path).map(\.line), [6, 8])
        XCTAssertEqual(set.mark(path: path, line: 8)?.condition, "i > 2")
    }
}
