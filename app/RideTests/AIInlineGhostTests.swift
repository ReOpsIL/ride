import XCTest

final class AIInlineGhostTests: XCTestCase {
    func testTypingThroughTheGhostKeepsTheRest() {
        let ghost = AIInlineGhost(anchor: 10, text: "total + 1;")
        let next = ghost.advanced(by: "tot")
        XCTAssertEqual(next?.location, 13)
        XCTAssertEqual(next?.remaining, "al + 1;")
        XCTAssertNil(ghost.advanced(by: "x"))
        XCTAssertNil(ghost.advanced(by: "total + 1;"))
    }

    func testNextChunkTakesOneWordOrOnePunctuationMark() {
        XCTAssertEqual(AIInlineGhost(anchor: 0, text: "values.iter()").nextChunk, "values")
        XCTAssertEqual(AIInlineGhost(anchor: 0, text: ".iter()").nextChunk, ".")
        XCTAssertEqual(AIInlineGhost(anchor: 0, text: "  let x").nextChunk, "  let")
        XCTAssertEqual(AIInlineGhost(anchor: 0, text: "\n    return x;").nextChunk, "\n    ")
    }

    func testCleaningDropsARepeatedLineStartAndTrailingSpace() {
        XCTAssertEqual(AIInlineGhost.cleaned("let x = 1;\n\n", lineBeforeCaret: "    let"), " x = 1;")
        XCTAssertEqual(AIInlineGhost.cleaned("x + 1", lineBeforeCaret: "  let y = "), "x + 1")
        XCTAssertNil(AIInlineGhost.cleaned("  \n", lineBeforeCaret: ""))
    }

    func testLinesSplitTheRemainingText() {
        XCTAssertEqual(AIInlineGhost(anchor: 0, text: "{\n    x\n}").lines, ["{", "    x", "}"])
    }
}
