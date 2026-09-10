import XCTest

final class CommentToggleTests: XCTestCase {
    private let rust = CommentTokens.tokens(for: .rust)

    func testTokensPerLanguage() {
        XCTAssertEqual(CommentTokens.tokens(for: .cpp), CommentTokens(line: "//", blockOpen: "/*", blockClose: "*/"))
        XCTAssertEqual(CommentTokens.tokens(for: .make), CommentTokens(line: "#", blockOpen: nil, blockClose: nil))
        XCTAssertEqual(CommentTokens.tokens(for: .markdown), CommentTokens(line: nil, blockOpen: "<!--", blockClose: "-->"))
        XCTAssertEqual(CommentTokens.tokens(for: .plain), .none)
    }

    func testCaretLineGetsCommentedAndCaretMoves() {
        XCTAssertEqual(line("  fo|o"), "  // fo|o")
        XCTAssertEqual(line("  // fo|o"), "  fo|o")
    }

    func testMixedIndentationUsesTheSmallestColumn() {
        XCTAssertEqual(line("[    a\n  b\n      c]"), "[  //   a\n  // b\n  //     c]")
    }

    func testUncommentHandlesMissingSpace() {
        XCTAssertEqual(line("[  // a\n  //b]"), "[  a\n  b]")
    }

    func testBlankLinesAreSkippedUnlessAllBlank() {
        XCTAssertEqual(line("[a\n\nb]"), "[// a\n\n// b]")
        XCTAssertEqual(line("[// a\n\n// b]"), "[a\n\nb]")
        XCTAssertEqual(line("|"), "// |")
    }

    func testPartiallyCommentedLinesGetCommented() {
        XCTAssertEqual(line("[// a\nb]"), "[// // a\n// b]")
    }

    func testSelectionEndingAtColumnZeroExcludesTheLastLine() {
        XCTAssertEqual(line("[a\nb\n]c"), "[// a\n// b\n]c")
    }

    func testHashLanguagesAndFallbacks() {
        XCTAssertEqual(line("[a]", .toml), "[# a]")
        XCTAssertEqual(line("[a]", .markdown), "[<!-- a -->]")
        XCTAssertEqual(line("[a]", .plain), "[a]")
    }

    func testBlockWrapsAndUnwraps() {
        XCTAssertEqual(block("x[ab]y"), "x[/* ab */]y")
        XCTAssertEqual(block("x[/* ab */]y"), "x[ab]y")
        XCTAssertEqual(block("[/*ab*/]"), "[ab]")
        XCTAssertEqual(block("a|b"), "[/* ab */]")
        XCTAssertEqual(block("[a]", .make), "[a]")
    }

    private func line(_ fixture: String, _ language: BufferLanguage = .rust) -> String {
        Fixture.apply(fixture) { CommentToggle.toggleLine($0, selection: $1, tokens: .tokens(for: language)) }
    }

    private func block(_ fixture: String, _ language: BufferLanguage = .rust) -> String {
        Fixture.apply(fixture) { CommentToggle.toggleBlock($0, selection: $1, tokens: .tokens(for: language)) }
    }
}
