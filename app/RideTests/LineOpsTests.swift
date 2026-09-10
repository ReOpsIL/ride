import XCTest

final class LineOpsTests: XCTestCase {
    func testFixtureRoundTrip() {
        let parsed = Fixture.parse("ab[cd]e")
        XCTAssertEqual(parsed.text, "abcde")
        XCTAssertEqual(parsed.selection, NSRange(location: 2, length: 2))
        XCTAssertEqual(Fixture.render(parsed.text, parsed.selection), "ab[cd]e")
        XCTAssertEqual(Fixture.parse("a|b").selection, NSRange(location: 1, length: 0))
    }

    func testOnlyLineFeedTerminatesLines() {
        XCTAssertEqual(LineSpan.lines("a\rb", NSRange(location: 0, length: 3)).count, 1)
        XCTAssertEqual(LineSpan.lines("a\nb", NSRange(location: 0, length: 3)).count, 2)
    }

    func testIndentShiftsEveryTouchedLine() {
        XCTAssertEqual(indent("[a\nb]\n"), "[  a\n  b]\n")
        XCTAssertEqual(indent("[a\nb\n]c"), "[  a\n  b\n]c")
        XCTAssertEqual(indent("[a\n\nb]"), "[  a\n\n  b]")
        XCTAssertEqual(indent("a|b"), "  a|b")
    }

    func testIndentWithTabsForMakefiles() {
        let result = Fixture.apply("[all:\n\techo]") { LineOps.indent($0, selection: $1, unit: "\t") }
        XCTAssertEqual(result, "[\tall:\n\t\techo]")
    }

    func testUnindentRemovesUpToWidthOrOneTab() {
        XCTAssertEqual(unindent("[    a\n  b\n\tc]"), "[a\nb\nc]")
        XCTAssertEqual(unindent("  |  a"), "|a")
        XCTAssertEqual(unindent("|a"), "|a")
        XCTAssertEqual(unindent("      x|"), "  x|")
    }

    func testDuplicateLinesAndSelections() {
        XCTAssertEqual(duplicate("a|b\nc"), "ab\na|b\nc")
        XCTAssertEqual(duplicate("a\nb|"), "a\nb\nb|")
        XCTAssertEqual(duplicate("x[ab]y"), "xab[ab]y")
        XCTAssertEqual(duplicate("[a\nb]\nc"), "a\nb\n[a\nb]\nc")
    }

    func testDeleteLinesKeepsTheColumn() {
        XCTAssertEqual(deleteLines("a\nb|x\nc"), "a\nc|")
        XCTAssertEqual(deleteLines("a\nb|"), "a|")
        XCTAssertEqual(deleteLines("ab|"), "|")
        XCTAssertEqual(deleteLines("[a\nb]\nc"), "|c")
    }

    func testJoinLinesCollapsesWhitespace() {
        XCTAssertEqual(joinLines("a|  \n    b"), "a| b")
        XCTAssertEqual(joinLines("a|\n\nb"), "a|\nb")
        XCTAssertEqual(joinLines("a\nb|"), "a\nb|")
        XCTAssertEqual(joinLines("[a\n  b\n  c]"), "[a b c]")
    }

    func testMoveLinesUpAndDown() {
        XCTAssertEqual(move("a\nb|\nc", up: true), "b|\na\nc")
        XCTAssertEqual(move("a\nb|", up: true), "b|\na")
        XCTAssertEqual(move("a|\nb\nc", up: false), "b\na|\nc")
        XCTAssertEqual(move("a|\nb", up: false), "b\na|")
        XCTAssertEqual(move("[a\nb]\nc", up: false), "c\n[a\nb]")
    }

    func testMoveLinesStopsAtTheEdges() {
        XCTAssertEqual(move("a|\nb", up: true), "a|\nb")
        XCTAssertEqual(move("a\nb|", up: false), "a\nb|")
        XCTAssertEqual(move("a\nb\n|", up: false), "a\nb\n|")
    }

    func testNewLineAfterAndBefore() {
        let after = Fixture.apply("a|b\nc") { LineOps.newLineAfter($0, caret: $1.location, indent: "  ") }
        XCTAssertEqual(after, "ab\n  |\nc")
        let before = Fixture.apply("a|b") { LineOps.newLineBefore($0, caret: $1.location, indent: "\t") }
        XCTAssertEqual(before, "\t|\nab")
    }

    func testToggleCaseCyclesLowerUpperLower() {
        XCTAssertEqual(toggleCase("[abc]"), "[ABC]")
        XCTAssertEqual(toggleCase("[ABC]"), "[abc]")
        XCTAssertEqual(toggleCase("[Abc]"), "[abc]")
        XCTAssertEqual(toggleCase("fo|o bar"), "FO|O bar")
        XCTAssertEqual(toggleCase("a |"), "a |")
    }

    func testSortLines() {
        XCTAssertEqual(sortLines("[c\nb\na]"), "[a\nb\nc]")
        XCTAssertEqual(sortLines("c\nb|\na"), "a\nb|\nc")
        XCTAssertEqual(sortLines("[c\nb\n]a"), "[b\nc\n]a")
    }

    private func indent(_ fixture: String) -> String {
        Fixture.apply(fixture) { LineOps.indent($0, selection: $1, unit: "  ") }
    }

    private func unindent(_ fixture: String) -> String {
        Fixture.apply(fixture) { LineOps.unindent($0, selection: $1, width: 4) }
    }

    private func duplicate(_ fixture: String) -> String {
        Fixture.apply(fixture) { LineOps.duplicate($0, selection: $1) }
    }

    private func deleteLines(_ fixture: String) -> String {
        Fixture.apply(fixture) { LineOps.deleteLines($0, selection: $1) }
    }

    private func joinLines(_ fixture: String) -> String {
        Fixture.apply(fixture) { LineOps.joinLines($0, selection: $1) }
    }

    private func move(_ fixture: String, up: Bool) -> String {
        Fixture.apply(fixture) { LineOps.moveLines($0, selection: $1, up: up) }
    }

    private func toggleCase(_ fixture: String) -> String {
        Fixture.apply(fixture) { LineOps.toggleCase($0, selection: $1) }
    }

    private func sortLines(_ fixture: String) -> String {
        Fixture.apply(fixture) { LineOps.sortLines($0, selection: $1) }
    }
}
