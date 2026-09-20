import XCTest

final class BuildParseTests: XCTestCase {
    func testCargoArgvAppendsTheMessageFormat() {
        XCTAssertEqual(
            BuildParse.cargoArgv(["cargo", "build"]),
            ["cargo", "build", BuildParse.cargoFormat]
        )
        XCTAssertEqual(BuildParse.cargoArgv(["make", "all"]), ["make", "all"])
    }

    func testCargoArgvKeepsAnExistingFormatAndStaysBeforeTheSeparator() {
        let existing = ["cargo", "build", "--message-format=json"]
        XCTAssertEqual(BuildParse.cargoArgv(existing), existing)
        XCTAssertEqual(
            BuildParse.cargoArgv(["cargo", "run", "--", "-v"]),
            ["cargo", "run", BuildParse.cargoFormat, "--", "-v"]
        )
    }

    func testRenderedUnwrapsCompilerMessages() {
        let json = "{\"reason\":\"compiler-message\",\"message\":{\"rendered\":\"error: bad\\n\"}}"
        XCTAssertEqual(BuildParse.rendered(json), "error: bad")
    }

    func testRenderedDropsMessagesWithoutRenderedText() {
        XCTAssertNil(BuildParse.rendered("{\"reason\":\"build-finished\",\"success\":true}"))
        XCTAssertNil(BuildParse.rendered("{not json"))
        XCTAssertTrue(BuildParse.isMessage("{\"reason\":\"x\"}"))
        XCTAssertFalse(BuildParse.isMessage(" warning: x"))
    }
}
