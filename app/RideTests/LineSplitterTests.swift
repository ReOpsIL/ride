import XCTest

final class LineSplitterTests: XCTestCase {
    func testWholeLinesSplit() {
        var splitter = LineSplitter()
        XCTAssertEqual(splitter.take(Array("a\nb\n".utf8)), ["a", "b"])
        XCTAssertNil(splitter.flush())
    }

    func testPartialLineIsCarried() {
        var splitter = LineSplitter()
        XCTAssertEqual(splitter.take(Array("one\ntw".utf8)), ["one"])
        XCTAssertEqual(splitter.take(Array("o\n".utf8)), ["two"])
    }

    func testMultiByteCharacterSplitAcrossChunks() {
        let bytes = Array("héllo → ok\n".utf8)
        let arrow = Array("→".utf8)
        XCTAssertEqual(arrow.count, 3)
        guard let cut = bytes.firstIndex(of: arrow[0]) else {
            return XCTFail("no arrow")
        }
        var splitter = LineSplitter()
        XCTAssertTrue(splitter.take(Array(bytes[..<(cut + 1)])).isEmpty)
        XCTAssertTrue(splitter.take(Array(bytes[(cut + 1)..<(cut + 2)])).isEmpty)
        XCTAssertEqual(splitter.take(Array(bytes[(cut + 2)...])), ["héllo → ok"])
    }

    func testFlushReturnsTailWithoutNewline() {
        var splitter = LineSplitter()
        XCTAssertTrue(splitter.take(Array("tail".utf8)).isEmpty)
        XCTAssertEqual(splitter.flush(), "tail")
        XCTAssertNil(splitter.flush())
    }

    func testEmptyLinesArePreserved() {
        var splitter = LineSplitter()
        XCTAssertEqual(splitter.take(Array("a\n\nb\n".utf8)), ["a", "", "b"])
    }

    func testCarriageReturnIsTrimmed() {
        var splitter = LineSplitter()
        XCTAssertEqual(splitter.take(Array("a\r\n".utf8)), ["a"])
    }
}
