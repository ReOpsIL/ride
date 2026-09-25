import XCTest
@testable import Ride

final class ShellPathTests: XCTestCase {
    func testLoginEntriesComeFirstThenInheritedThenFallback() {
        let merged = ShellPath.merged(login: "/a:/b", inherited: "/c", fallback: ["/d"])
        XCTAssertEqual(merged, "/a:/b:/c:/d")
    }

    func testDuplicatesKeepFirstPosition() {
        let merged = ShellPath.merged(login: "/a:/c", inherited: "/c:/a:/b", fallback: ["/b", "/a"])
        XCTAssertEqual(merged, "/a:/c:/b")
    }

    func testEmptyEntriesAreDropped() {
        let merged = ShellPath.merged(login: ":/a::", inherited: "", fallback: [])
        XCTAssertEqual(merged, "/a")
    }

    func testMissingLoginFallsBackToInheritedAndDefaults() {
        let merged = ShellPath.merged(login: nil, inherited: "/usr/bin", fallback: ["/opt/x", "/usr/bin"])
        XCTAssertEqual(merged, "/usr/bin:/opt/x")
    }

    func testDefaultFallbackIncludesCargoBin() {
        XCTAssertTrue(ShellPath.fallbackDirectories.contains { $0.hasSuffix("/.cargo/bin") })
    }
}
