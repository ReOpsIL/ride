import XCTest

final class ConsoleLinksTests: XCTestCase {
    func testRelativePathWithLineAndColumn() {
        let links = ConsoleLinks.links(in: "  --> src/main.rs:10:5")
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.path, "src/main.rs")
        XCTAssertEqual(links.first?.line, 10)
        XCTAssertEqual(links.first?.column, 5)
    }

    func testClangStyleDiagnostic() {
        let links = ConsoleLinks.links(in: "src/geo.cpp:12:3: error: expected ';'")
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.path, "src/geo.cpp")
        XCTAssertEqual(links.first?.line, 12)
        XCTAssertEqual(links.first?.column, 3)
    }

    func testAbsolutePathWithoutColumn() {
        let links = ConsoleLinks.links(in: "panicked at /tmp/demo/src/lib.rs:42:")
        XCTAssertEqual(links.first?.path, "/tmp/demo/src/lib.rs")
        XCTAssertEqual(links.first?.line, 42)
        XCTAssertNil(links.first?.column)
    }

    func testRangeCoversTheMatchOnly() {
        let text = "at src/main.rs:7:1 done"
        guard let link = ConsoleLinks.links(in: text).first else {
            return XCTFail("no link")
        }
        XCTAssertEqual((text as NSString).substring(with: NSRange(location: link.start, length: link.length)), "src/main.rs:7:1")
    }

    func testTextWithoutAPathHasNoLinks() {
        XCTAssertTrue(ConsoleLinks.links(in: "error: aborting due to 1 error").isEmpty)
        XCTAssertTrue(ConsoleLinks.links(in: "took 1.5:30 seconds").isEmpty)
    }

    func testTwoLinksOnOneLine() {
        let links = ConsoleLinks.links(in: "src/a.rs:1:1 and src/b.rs:2:2")
        XCTAssertEqual(links.map(\.path), ["src/a.rs", "src/b.rs"])
    }

    func testHostAndPortIsNotALink() {
        XCTAssertTrue(ConsoleLinks.links(in: "listening on example.com:8080").isEmpty)
        XCTAssertTrue(ConsoleLinks.links(in: "proxy to api.internal.dev:443/health").isEmpty)
    }

    func testKnownSourceExtensionsStayLinks() {
        XCTAssertEqual(ConsoleLinks.links(in: "build.rs:3:1").first?.path, "build.rs")
        XCTAssertEqual(ConsoleLinks.links(in: "CMakeLists.txt:9:").first?.line, 9)
    }

    func testAbsolutePathResolutionKeepsAbsolute() {
        let link = ConsoleLink(path: "/tmp/demo/src/main.rs", line: 1, column: nil, start: 0, length: 0)
        XCTAssertEqual(ConsoleLinks.absolutePath(link, root: "/other"), "/tmp/demo/src/main.rs")
    }

    func testRelativePathResolvesAgainstRoot() {
        let link = ConsoleLink(path: "src/main.rs", line: 1, column: nil, start: 0, length: 0)
        XCTAssertEqual(ConsoleLinks.absolutePath(link, root: "/tmp/demo"), "/tmp/demo/src/main.rs")
    }
}
