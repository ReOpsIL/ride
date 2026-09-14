import XCTest

private final class TextBox: TextUndoTarget {
    var undoText: String
    var commits = 0

    init(_ text: String) {
        undoText = text
    }
}

final class BufferTextUndoTests: XCTestCase {
    private func commit(_ box: TextBox) {
        box.commits += 1
    }

    func testUndoRestoresPreviousText() {
        let box = TextBox("fn record()")
        let manager = UndoManager()
        manager.groupsByEvent = false
        BufferTextUndo.apply("fn logged()", to: box, undo: manager, commit: commit)
        XCTAssertEqual(box.undoText, "fn logged()")
        XCTAssertEqual(box.commits, 1)
        XCTAssertTrue(manager.canUndo)
        manager.undo()
        XCTAssertEqual(box.undoText, "fn record()")
        XCTAssertEqual(box.commits, 2)
    }

    func testRedoReappliesText() {
        let box = TextBox("a")
        let manager = UndoManager()
        manager.groupsByEvent = false
        BufferTextUndo.apply("b", to: box, undo: manager, commit: commit)
        manager.undo()
        XCTAssertTrue(manager.canRedo)
        manager.redo()
        XCTAssertEqual(box.undoText, "b")
    }

    func testUnchangedTextRegistersNothing() {
        let box = TextBox("same")
        let manager = UndoManager()
        BufferTextUndo.apply("same", to: box, undo: manager, commit: commit)
        XCTAssertFalse(manager.canUndo)
        XCTAssertEqual(box.commits, 0)
    }

    func testMissingManagerStillApplies() {
        let box = TextBox("a")
        BufferTextUndo.apply("b", to: box, undo: nil, commit: commit)
        XCTAssertEqual(box.undoText, "b")
        XCTAssertEqual(box.commits, 1)
    }
}
