import XCTest

final class LineEndingsTests: XCTestCase {
    func testKeepWritesCRLFWhenTheBufferLoadedCRLF() {
        let result = LineEndings.encode(text: "a\nb\n", usesCRLF: true, policy: LineEndings.keep)
        XCTAssertEqual(result.text, "a\r\nb\r\n")
        XCTAssertTrue(result.usesCRLF)
    }

    func testKeepWritesLFWhenTheBufferLoadedLF() {
        let result = LineEndings.encode(text: "a\nb\n", usesCRLF: false, policy: LineEndings.keep)
        XCTAssertEqual(result.text, "a\nb\n")
        XCTAssertFalse(result.usesCRLF)
    }

    func testLFPolicyWritesLFAndClearsTheCRLFFlag() {
        let result = LineEndings.encode(text: "a\nb\n", usesCRLF: true, policy: LineEndings.lf)
        XCTAssertEqual(result.text, "a\nb\n")
        XCTAssertFalse(result.usesCRLF)
    }

    func testUnknownPolicyBehavesLikeKeep() {
        let result = LineEndings.encode(text: "a\nb", usesCRLF: true, policy: "crlf")
        XCTAssertEqual(result.text, "a\r\nb")
        XCTAssertTrue(result.usesCRLF)
    }

    func testNormalizedTurnsCRLFAndLoneCRIntoLF() {
        XCTAssertEqual(LineEndings.normalized("a\r\nb\rc\n"), "a\nb\nc\n")
        XCTAssertEqual(LineEndings.normalized("plain\n"), "plain\n")
    }

    func testCRLFBufferRoundTripsWithoutDoubledCarriageReturns() {
        let pasted = LineEndings.normalized("x\r\ny")
        let result = LineEndings.encode(text: pasted, usesCRLF: true, policy: LineEndings.keep)
        XCTAssertEqual(result.text, "x\r\ny")
    }
}
