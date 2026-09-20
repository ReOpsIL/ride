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
}
