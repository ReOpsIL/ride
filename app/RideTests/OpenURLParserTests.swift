import XCTest
@testable import Ride

final class OpenURLParserTests: XCTestCase {
    private func request(_ text: String) -> OpenRequest? {
        guard let url = URL(string: text) else {
            return nil
        }
        return OpenURLParser.request(from: url)
    }

    func testPathLineAndColumn() {
        XCTAssertEqual(
            request("ride://open?path=/p/src/main.rs&line=12&column=3"),
            OpenRequest(path: "/p/src/main.rs", line: 12, column: 3)
        )
    }

    func testPathOnlyAndPercentEncoding() {
        XCTAssertEqual(request("ride://open?path=/p/a"), OpenRequest(path: "/p/a", line: nil, column: nil))
        XCTAssertEqual(
            request("ride://open?path=/p/a%20b/c%C3%BC.rs&line=2")?.path,
            "/p/a b/cü.rs"
        )
    }

    func testBadInputIsRejected() {
        XCTAssertNil(request("ride://open"))
        XCTAssertNil(request("ride://open?path="))
        XCTAssertNil(request("ride://close?path=/p/a"))
        XCTAssertNil(request("file:///p/a"))
        XCTAssertNil(request("ride://open?path=/p/a&line=zero"))
        XCTAssertNil(request("ride://open?path=/p/a&line=0"))
        XCTAssertNil(request("ride://open?path=/p/a&line=2&column=-1"))
    }
}
