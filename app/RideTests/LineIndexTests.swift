import XCTest

final class LineIndexTests: XCTestCase {
    func testLineAndColumn() {
        let index = LineIndex()
        index.refresh("ab\ncd\n\nxyz" as NSString)
        XCTAssertEqual(index.lineCount, 4)
        XCTAssertEqual(index.line(at: 0), 1)
        XCTAssertEqual(index.line(at: 2), 1)
        XCTAssertEqual(index.line(at: 3), 2)
        XCTAssertEqual(index.line(at: 6), 3)
        XCTAssertEqual(index.line(at: 9), 4)
        XCTAssertEqual(index.column(at: 9), 3)
    }

    func testRefreshOnlyWhenInvalidated() {
        let index = LineIndex()
        index.refresh("a\nb" as NSString)
        XCTAssertEqual(index.lineCount, 2)
        index.refresh("a\nb\nc" as NSString)
        XCTAssertEqual(index.lineCount, 3)
        index.invalidate()
        index.refresh("x" as NSString)
        XCTAssertEqual(index.lineCount, 1)
    }

    func testUtf16MapMatchesSlowPath() {
        let text = "let é = \"🦀\";\nfn ok() {}\n"
        let map = Utf16Map(text)
        var byte = 0
        for scalar in text.unicodeScalars {
            XCTAssertEqual(map.utf16(byte: byte), Utf16.utf16Offset(in: text, utf8: byte), "byte \(byte)")
            byte += scalar.utf8.count
        }
        XCTAssertEqual(map.utf16(byte: byte), text.utf16.count)
        let ascii = Utf16Map("plain ascii")
        XCTAssertEqual(ascii.utf16(byte: 7), 7)
    }
}
