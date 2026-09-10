import XCTest

final class CompletionNarrowingTests: XCTestCase {
    private let names = ["HashMap", "Hash", "hasher", "read_line", "Vec"]

    func testCaseInsensitivePrefixKeepsOrder() {
        XCTAssertEqual(CompletionNarrowing.filter(names, prefix: "ha") { $0 }, ["HashMap", "Hash", "hasher"])
        XCTAssertEqual(CompletionNarrowing.filter(names, prefix: "HASHM") { $0 }, ["HashMap"])
    }

    func testEmptyPrefixKeepsEverything() {
        XCTAssertEqual(CompletionNarrowing.filter(names, prefix: "") { $0 }, names)
    }

    func testHumpMatch() {
        XCTAssertEqual(CompletionNarrowing.hump("HashMap"), "hm")
        XCTAssertEqual(CompletionNarrowing.hump("read_line"), "rl")
        XCTAssertEqual(CompletionNarrowing.hump("_private"), "p")
        XCTAssertEqual(CompletionNarrowing.filter(names, prefix: "hm") { $0 }, ["HashMap"])
        XCTAssertEqual(CompletionNarrowing.filter(names, prefix: "rl") { $0 }, ["read_line"])
    }

    func testNoMatchIsEmpty() {
        XCTAssertTrue(CompletionNarrowing.filter(names, prefix: "zz") { $0 }.isEmpty)
    }

    func testSelectionKeepsPreviousRow() {
        let filtered = CompletionNarrowing.filter(names, prefix: "ha") { $0 }
        XCTAssertEqual(CompletionNarrowing.selection(in: filtered, previous: "hasher") { $0 }, 2)
        XCTAssertEqual(CompletionNarrowing.selection(in: filtered, previous: "Vec") { $0 }, 0)
        XCTAssertEqual(CompletionNarrowing.selection(in: filtered, previous: nil) { $0 }, 0)
    }
}
