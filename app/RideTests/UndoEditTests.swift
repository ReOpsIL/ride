import XCTest

final class UndoEditTests: XCTestCase {
    func testInverseOfAnInsertionRemovesIt() {
        let edit = UndoEdit.inverse(before: "ab", after: "axb")
        XCTAssertEqual(edit, UndoEdit(range: NSRange(location: 1, length: 1), text: ""))
    }

    func testInverseOfADeletionRestoresIt() {
        let edit = UndoEdit.inverse(before: "axb", after: "ab")
        XCTAssertEqual(edit, UndoEdit(range: NSRange(location: 1, length: 0), text: "x"))
    }

    func testInverseOfAReplacementRestoresTheOldText() {
        let edit = UndoEdit.inverse(before: "let a = 1", after: "let bb = 1")
        XCTAssertEqual(edit, UndoEdit(range: NSRange(location: 4, length: 2), text: "a"))
    }

    func testInverseOfNoChangeIsNil() {
        XCTAssertNil(UndoEdit.inverse(before: "ab", after: "ab"))
    }

    func testCaretLandsAfterTheRestoredText() {
        let edit = UndoEdit(range: NSRange(location: 3, length: 4), text: "xy")
        XCTAssertEqual(edit.caret, 5)
    }

    func testTypingRunExtendsWithTheNextCharacter() {
        let run = UndoEdit(range: NSRange(location: 2, length: 1), text: "")
        let next = UndoEdit(range: NSRange(location: 3, length: 1), text: "")
        XCTAssertEqual(run.extended(by: next), UndoEdit(range: NSRange(location: 2, length: 2), text: ""))
    }

    func testTypingRunKeepsExtending() {
        var run = UndoEdit(range: NSRange(location: 0, length: 1), text: "")
        for location in 1...3 {
            guard let merged = run.extended(by: UndoEdit(range: NSRange(location: location, length: 1), text: "")) else {
                return XCTFail("run stopped at \(location)")
            }
            run = merged
        }
        XCTAssertEqual(run.range, NSRange(location: 0, length: 4))
    }

    func testTypingRunStopsAtAGap() {
        let run = UndoEdit(range: NSRange(location: 2, length: 1), text: "")
        let next = UndoEdit(range: NSRange(location: 7, length: 1), text: "")
        XCTAssertNil(run.extended(by: next))
    }

    func testTypingRunStopsAtADeletion() {
        let run = UndoEdit(range: NSRange(location: 2, length: 1), text: "")
        let next = UndoEdit(range: NSRange(location: 3, length: 0), text: "x")
        XCTAssertNil(run.extended(by: next))
    }

    func testAReplacementNeverStartsATypingRun() {
        let edit = UndoEdit(range: NSRange(location: 2, length: 1), text: "x")
        XCTAssertFalse(edit.isTyping)
        XCTAssertNil(edit.extended(by: UndoEdit(range: NSRange(location: 3, length: 1), text: "")))
    }
}
