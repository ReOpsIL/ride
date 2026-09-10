import XCTest

final class SnippetParserTests: XCTestCase {
    func testPlaceholdersWithDefaults() {
        let snippet = SnippetParser.parse("foo(${1:a}, ${2:b})$0")
        XCTAssertEqual(snippet.text, "foo(a, b)")
        XCTAssertEqual(snippet.stops, [
            SnippetStop(index: 1, range: NSRange(location: 4, length: 1)),
            SnippetStop(index: 2, range: NSRange(location: 7, length: 1)),
        ])
        XCTAssertEqual(snippet.finalOffset, 9)
    }

    func testFinalStopInsideText() {
        let snippet = SnippetParser.parse("name!($0)")
        XCTAssertEqual(snippet.text, "name!()")
        XCTAssertTrue(snippet.stops.isEmpty)
        XCTAssertEqual(snippet.finalOffset, 6)
    }

    func testMissingFinalStopIsTextEnd() {
        let snippet = SnippetParser.parse("Vec::new()")
        XCTAssertEqual(snippet.finalOffset, "Vec::new()".utf16.count)
    }

    func testEscapes() {
        let snippet = SnippetParser.parse("\\$HOME \\\\ ${1:a\\}b}")
        XCTAssertEqual(snippet.text, "$HOME \\ a}b")
        XCTAssertEqual(snippet.stops, [SnippetStop(index: 1, range: NSRange(location: 8, length: 3))])
    }

    func testStopsAreOrderedByIndex() {
        let snippet = SnippetParser.parse("${2:b} ${1:a}")
        XCTAssertEqual(snippet.stops.map(\.index), [1, 2])
        XCTAssertEqual(snippet.stops.first?.range, NSRange(location: 2, length: 1))
    }

    func testBareAndEmptyStops() {
        let snippet = SnippetParser.parse("for $1 in ${2} {}")
        XCTAssertEqual(snippet.text, "for  in  {}")
        XCTAssertEqual(snippet.stops, [
            SnippetStop(index: 1, range: NSRange(location: 4, length: 0)),
            SnippetStop(index: 2, range: NSRange(location: 8, length: 0)),
        ])
    }

    func testDuplicateIndexKeepsFirst() {
        let snippet = SnippetParser.parse("${1:x} = ${1:x}")
        XCTAssertEqual(snippet.text, "x = x")
        XCTAssertEqual(snippet.stops.count, 1)
    }

    func testMalformedIsLiteral() {
        XCTAssertEqual(SnippetParser.parse("${1:abc").text, "${1:abc")
        XCTAssertEqual(SnippetParser.parse("cost $").text, "cost $")
        XCTAssertEqual(SnippetParser.parse("${x}").text, "${x}")
    }

    func testUtf16Offsets() {
        let snippet = SnippetParser.parse("🦀(${1:a})")
        XCTAssertEqual(snippet.stops.first?.range, NSRange(location: 3, length: 1))
    }
}
