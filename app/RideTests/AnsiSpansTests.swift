import XCTest

final class AnsiSpansTests: XCTestCase {
    func testPlainTextIsOneSpan() {
        XCTAssertEqual(AnsiSpans.parse("hello"), [AnsiSpan(text: "hello")])
    }

    func testColorRunsAreSeparated() {
        let spans = AnsiSpans.parse("a\u{1B}[31merror\u{1B}[0mb")
        XCTAssertEqual(spans, [
            AnsiSpan(text: "a"),
            AnsiSpan(text: "error", color: .red),
            AnsiSpan(text: "b"),
        ])
    }

    func testBoldAndColorCombine() {
        let spans = AnsiSpans.parse("\u{1B}[1;33mwarning\u{1B}[0m")
        XCTAssertEqual(spans, [AnsiSpan(text: "warning", color: .yellow, bold: true)])
    }

    func testBrightColorsFoldToTheEightAndSetBold() {
        let spans = AnsiSpans.parse("\u{1B}[92mok")
        XCTAssertEqual(spans, [AnsiSpan(text: "ok", color: .green, bold: true)])
    }

    func testDefaultForegroundClearsColorOnly() {
        let spans = AnsiSpans.parse("\u{1B}[1m\u{1B}[34mx\u{1B}[39my")
        XCTAssertEqual(spans, [
            AnsiSpan(text: "x", color: .blue, bold: true),
            AnsiSpan(text: "y", color: nil, bold: true),
        ])
    }

    func testAdjacentEqualRunsMerge() {
        let spans = AnsiSpans.parse("\u{1B}[31ma\u{1B}[31mb")
        XCTAssertEqual(spans, [AnsiSpan(text: "ab", color: .red)])
    }

    func testUnknownSequenceIsDropped() {
        XCTAssertEqual(AnsiSpans.parse("a\u{1B}[2Kb"), [AnsiSpan(text: "ab")])
    }

    func testPlainStripsEscapes() {
        XCTAssertEqual(AnsiSpans.plain("\u{1B}[31merror\u{1B}[0m: bad"), "error: bad")
    }
}
