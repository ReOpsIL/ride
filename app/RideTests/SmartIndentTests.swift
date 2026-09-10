import XCTest

final class SmartIndentTests: XCTestCase {
    func testNewlineKeepsIndentation() {
        XCTAssertEqual(newline("  a|"), "  a\n  |")
        XCTAssertEqual(newline("a|b"), "a\n|b")
    }

    func testNewlineAddsAUnitAfterOpeners() {
        XCTAssertEqual(newline("fn f() {|"), "fn f() {\n    |")
        XCTAssertEqual(newline("  foo(|"), "  foo(\n      |")
        XCTAssertEqual(newline("a =>|"), "a =>\n    |")
        XCTAssertEqual(newline("all:|", unit: "\t"), "all:\n\t|")
        XCTAssertEqual(newline("all:|"), "all:\n|")
    }

    func testNewlineBetweenBracesOpensABlock() {
        XCTAssertEqual(newline("{|}"), "{\n    |\n}")
        XCTAssertEqual(newline("  f(|)"), "  f(\n      |\n  )")
    }

    func testNewlineContinuesCommentPrefixes() {
        XCTAssertEqual(newline("/// doc|"), "/// doc\n/// |")
        XCTAssertEqual(newline("  //! crate|"), "  //! crate\n  //! |")
        XCTAssertEqual(newline("# note|", lineComment: "#"), "# note\n# |")
        XCTAssertEqual(newline("# note|"), "# note\n|")
        XCTAssertEqual(newline("// plain|"), "// plain\n|")
    }

    func testNewlineContinuesBlockComments() {
        XCTAssertEqual(newline("/* a|"), "/* a\n * |")
        XCTAssertEqual(newline("/*\n * b|"), "/*\n * b\n * |")
        XCTAssertEqual(newline(" * x|"), " * x\n |")
        XCTAssertEqual(newline("/* a */|"), "/* a */\n|")
    }

    func testClosingBraceDedentsAWhitespaceOnlyLine() {
        XCTAssertEqual(closing("{\n    a\n    |", "}"), "{\n    a\n}|")
        XCTAssertEqual(closing("  {\n      |", "}"), "  {\n  }|")
        XCTAssertEqual(closing("f(\n    g()\n    |", ")"), "f(\n    g()\n)|")
        let square = SmartIndent.closingBrace("x[\n   ", caret: 5, typed: "]")
        let expected = EditResult(changes: [TextChange(range: NSRange(location: 3, length: 3), text: "]")], selection: NSRange(location: 4, length: 0))
        XCTAssertEqual(square, expected)
    }

    func testClosingBraceLeavesOtherLinesAlone() {
        XCTAssertNil(SmartIndent.closingBrace("    ", caret: 4, typed: "}"))
        XCTAssertNil(SmartIndent.closingBrace("{\n  a", caret: 5, typed: "}"))
        XCTAssertNil(SmartIndent.closingBrace("{\n  ", caret: 4, typed: "x"))
    }

    func testAutoIndentReindentsFromThePreviousLine() {
        XCTAssertEqual(auto("{\n[a\nb\n}]"), "{\n[  a\n  b\n}]")
        XCTAssertEqual(auto("    x|"), "x|")
        XCTAssertEqual(auto("a {\n  b {\n[c\n}\n}]"), "a {\n  b {\n[    c\n  }\n}]")
        XCTAssertEqual(auto("a\n[\n  b]"), "a\n[\nb]")
    }

    private func newline(_ fixture: String, unit: String = "    ", lineComment: String? = nil) -> String {
        Fixture.apply(fixture) { SmartIndent.newline($0, caret: $1.location, unit: unit, lineComment: lineComment) }
    }

    private func closing(_ fixture: String, _ typed: String) -> String {
        Fixture.apply(fixture) { SmartIndent.closingBrace($0, caret: $1.location, typed: typed) ?? .keep($1) }
    }

    private func auto(_ fixture: String) -> String {
        Fixture.apply(fixture) { SmartIndent.autoIndent($0, selection: $1, unit: "  ") }
    }
}
