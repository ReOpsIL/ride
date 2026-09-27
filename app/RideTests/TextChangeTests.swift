import XCTest

final class TextChangeTests: XCTestCase {
    private func change(_ location: Int, _ length: Int, _ text: String) -> TextChange {
        TextChange(range: NSRange(location: location, length: length), text: text)
    }

    func testUnsortedChangesApplyAsIfSorted() {
        XCTAssertEqual(EditResult.applying([change(6, 1, "Z"), change(0, 1, "A")], to: "abcdefg"), "AbcdefZ")
    }

    func testEditResultKeepsItsChangesInDocumentOrder() {
        let result = EditResult(changes: [change(6, 1, "Z"), change(0, 1, "A")], selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(result.changes, [change(0, 1, "A"), change(6, 1, "Z")])
    }

    func testOverlappingChangesAreRejected() {
        let changes = [change(0, 3, "x"), change(2, 2, "y")]
        XCTAssertNil(TextChange.ordered(changes))
        XCTAssertEqual(EditResult.applying(changes, to: "abcdef"), "abcdef")
        XCTAssertEqual(EditResult(changes: changes, selection: NSRange(location: 1, length: 0)).changes, [])
    }

    func testInsertionsAtTheSameOffsetKeepTheirOrder() {
        XCTAssertEqual(EditResult.applying([TextChange(insert: "1", at: 2), TextChange(insert: "2", at: 2)], to: "abcd"), "ab12cd")
    }

    func testMappingSortsBeforeShiftingTheCaret() {
        let result = EditResult.mapping(NSRange(location: 3, length: 0), through: [TextChange(insert: "xx", at: 5), TextChange(insert: "y", at: 1)])
        XCTAssertEqual(result.selection, NSRange(location: 4, length: 0))
    }
}
