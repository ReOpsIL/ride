import XCTest

final class AIChatLocationTests: XCTestCase {
    func testParsesPathAndLine() {
        let location = AIChatLocation("src/main.rs:12")
        XCTAssertEqual(location?.path, "src/main.rs")
        XCTAssertEqual(location?.line, 12)
        XCTAssertEqual(AIChatLocation("C:/x.rs:3")?.path, "C:/x.rs")
    }

    func testRejectsMissingOrZeroLines() {
        XCTAssertNil(AIChatLocation("src/main.rs"))
        XCTAssertNil(AIChatLocation("src/main.rs:0"))
        XCTAssertNil(AIChatLocation(":4"))
    }
}
