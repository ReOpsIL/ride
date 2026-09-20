import XCTest

final class AICommentPromptTests: XCTestCase {
    private let rust = CommentTokens(line: "//", blockOpen: "/*", blockClose: "*/")

    func testCaretOnCommentLineJoinsTheCommentRun() {
        let text = "fn a() {}\n// I want to build\n// a debugger\nfn b() {}"
        let caret = (text as NSString).range(of: "a debugger").location
        XCTAssertEqual(AICommentPrompt.extract(text, caret: caret, tokens: rust), "I want to build\na debugger")
    }

    func testCommentAboveTheCaretLineIsUsed() {
        let text = "/// whats the bug in the function\nfn b() {\n    1\n}"
        let caret = (text as NSString).range(of: "fn b").location + 3
        XCTAssertEqual(AICommentPrompt.extract(text, caret: caret, tokens: rust), "whats the bug in the function")
        XCTAssertNil(AICommentPrompt.extract(text, caret: text.utf16.count - 1, tokens: rust))
    }

    func testBlockCommentsAndHashComments() {
        XCTAssertEqual(AICommentPrompt.extract("/* explain this */\nlet x = 1;", caret: 3, tokens: rust), "explain this")
        XCTAssertEqual(AICommentPrompt.extract("/*\n * one\n * two\n */\nx", caret: 6, tokens: rust), "one\ntwo")
        let hash = CommentTokens(line: "#", blockOpen: nil, blockClose: nil)
        XCTAssertEqual(AICommentPrompt.extract("# add a target\nall:", caret: 2, tokens: hash), "add a target")
    }

    func testAnswerCodeExtractsFencedBlocksOrFallsBackToText() {
        let answer = "Use this:\n```rust\nfn x() {}\n```\nand\n```\nlet y = 1;\n```"
        XCTAssertEqual(AIAnswerText.code(in: answer), "fn x() {}\n\nlet y = 1;")
        XCTAssertEqual(AIAnswerText.code(in: "plain answer"), "plain answer")
    }
}
