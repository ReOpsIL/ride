import XCTest

private struct Span: ByteSpan, Equatable {
    let startByte: UInt32
    let endByte: UInt32
}

final class EditJournalTests: XCTestCase {
    func testMapKeepsEarlierPositionsAndShiftsLaterOnes() {
        let edit = ByteEdit(start: 10, oldEnd: 12, newEnd: 15)
        XCTAssertEqual(edit.map(5, towardEnd: false), 5)
        XCTAssertEqual(edit.map(10, towardEnd: true), 10)
        XCTAssertEqual(edit.map(12, towardEnd: false), 15)
        XCTAssertEqual(edit.map(20, towardEnd: false), 23)
    }

    func testMapClampsPositionsInsideTheReplacedText() {
        let edit = ByteEdit(start: 10, oldEnd: 12, newEnd: 15)
        XCTAssertEqual(edit.map(11, towardEnd: false), 10)
        XCTAssertEqual(edit.map(11, towardEnd: true), 15)
    }

    func testJournalReturnsTheEditsRecordedAfterAMark() {
        var journal = EditJournal()
        journal.record(ByteEdit(start: 0, oldEnd: 0, newEnd: 1))
        let mark = journal.generation
        journal.record(ByteEdit(start: 1, oldEnd: 1, newEnd: 2))
        journal.record(ByteEdit(start: 2, oldEnd: 2, newEnd: 3))
        XCTAssertEqual(journal.edits(since: mark), [
            ByteEdit(start: 1, oldEnd: 1, newEnd: 2),
            ByteEdit(start: 2, oldEnd: 2, newEnd: 3),
        ])
        XCTAssertEqual(journal.edits(since: journal.generation), [])
    }

    func testJournalCannotRebaseBeyondItsCapacity() {
        var journal = EditJournal()
        for _ in 0 ... EditJournal.capacity {
            journal.record(ByteEdit(start: 0, oldEnd: 0, newEnd: 1))
        }
        XCTAssertNil(journal.edits(since: 0))
        XCTAssertEqual(journal.edits(since: 1)?.count, EditJournal.capacity)
    }

    func testCoveringStretchesRangesOverAnOverlappingEdit() {
        let edit = ByteEdit(start: 4, oldEnd: 6, newEnd: 10)
        let out = edit.covering([Span(startByte: 2, endByte: 5), Span(startByte: 8, endByte: 9)]) {
            Span(startByte: $1, endByte: $2)
        }
        XCTAssertEqual(out, [Span(startByte: 2, endByte: 10), Span(startByte: 12, endByte: 13)])
    }

    func testShiftedDropsSpansTheEditTouches() {
        let edit = ByteEdit(start: 4, oldEnd: 6, newEnd: 10)
        let out = edit.shifted([Span(startByte: 0, endByte: 3), Span(startByte: 5, endByte: 7), Span(startByte: 6, endByte: 8)]) {
            Span(startByte: $1, endByte: $2)
        }
        XCTAssertEqual(out, [Span(startByte: 0, endByte: 3), Span(startByte: 10, endByte: 12)])
    }

    func testCaretOfALaterEditMovesPastEarlierInsertions() {
        let declaration = ByteEdit(start: 10, oldEnd: 10, newEnd: 30)
        let replacement = ByteEdit(start: 40, oldEnd: 48, newEnd: 45)
        XCTAssertEqual(ByteEdit.caret(40, of: replacement, among: [declaration, replacement]), 60)
        XCTAssertEqual(ByteEdit.caret(12, of: declaration, among: [declaration, replacement]), 12)
    }
}
