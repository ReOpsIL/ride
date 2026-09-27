import XCTest

final class EditPointsTests: XCTestCase {
    private let text = "fn é() {\n    let 🦀 = 1;\n}\n"

    private func point(_ text: String, _ byte: Int) -> TextPoint {
        let (row, column) = Utf16.point(in: text, utf8: byte)
        return TextPoint(byte: byte, row: row, column: column)
    }

    private func expected(_ range: NSRange, _ inserted: String) -> [TextPoint] {
        let start = Utf16.utf8Offset(in: text, utf16: range.location)
        let oldEnd = Utf16.utf8Offset(in: text, utf16: NSMaxRange(range))
        let after = (text as NSString).replacingCharacters(in: range, with: inserted)
        return [point(text, start), point(text, oldEnd), point(after, start + inserted.utf8.count)]
    }

    private func check(_ range: NSRange, _ inserted: String, file: StaticString = #filePath, line: UInt = #line) {
        let points = EditPoints(before: text, utf16Range: range, inserted: inserted)
        XCTAssertEqual([points.start, points.oldEnd, points.newEnd], expected(range, inserted), file: file, line: line)
    }

    func testInsertionAtTheStart() {
        check(NSRange(location: 0, length: 0), "x")
    }

    func testReplacingAMultibyteCharacter() {
        check((text as NSString).range(of: "é"), "e")
    }

    func testReplacingASurrogatePairWithLines() {
        check((text as NSString).range(of: "🦀"), "crab\nnext")
    }

    func testDeletionAcrossALineBreak() {
        check(NSRange(location: 7, length: 6), "")
    }

    func testInsertionAtTheEnd() {
        check(NSRange(location: (text as NSString).length, length: 0), "\n")
    }
}
