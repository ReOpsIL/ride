import XCTest

final class QueryIdTests: XCTestCase {
    func testStaleResponseIsDropped() {
        XCTAssertFalse(CompletionGate.accept(3, latest: 5))
    }

    func testLatestResponseIsAccepted() {
        XCTAssertTrue(CompletionGate.accept(5, latest: 5))
    }

    func testUnknownFutureResponseIsDropped() {
        XCTAssertFalse(CompletionGate.accept(6, latest: 5))
    }
}
