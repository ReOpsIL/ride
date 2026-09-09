import XCTest

final class DiagnosticRangeTests: XCTestCase {
    func testMapsUtf8BytesToUtf16() {
        let text = "let é = 🦀;\nlet x = 1;"
        let range = DiagnosticRange.nsRange(in: text, byteStart: 4, byteEnd: 6)
        XCTAssertEqual(range, NSRange(location: 4, length: 1))
        let crab = DiagnosticRange.nsRange(in: text, byteStart: 9, byteEnd: 13)
        XCTAssertEqual(crab, NSRange(location: 8, length: 2))
    }

    func testEmptySpanGetsOneCharacter() {
        XCTAssertEqual(DiagnosticRange.nsRange(in: "abc", byteStart: 1, byteEnd: 1), NSRange(location: 1, length: 1))
    }

    func testOutOfBoundsIsNil() {
        XCTAssertNil(DiagnosticRange.nsRange(in: "abc", byteStart: 3, byteEnd: 5))
        XCTAssertNil(DiagnosticRange.nsRange(in: "", byteStart: 0, byteEnd: 0))
        XCTAssertEqual(DiagnosticRange.nsRange(in: "abc", byteStart: 2, byteEnd: 9), NSRange(location: 2, length: 1))
    }
}
