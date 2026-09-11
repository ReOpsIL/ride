import XCTest

final class DocPageTests: XCTestCase {
    func testHtmlWrapsTitleAsH1() {
        let html = DocPage.html(title: "Counter", signature: "struct Counter", body: "<p>Counts</p>")
        XCTAssertTrue(html.contains("<h1>Counter</h1>"), html)
        XCTAssertTrue(html.contains("<pre><code>struct Counter</code></pre>"), html)
        XCTAssertTrue(html.contains("<p>Counts</p>"), html)
    }

    func testHtmlEscapesTitleAndSignature() {
        let html = DocPage.html(title: "A<B>", signature: "foo & bar", body: "")
        XCTAssertTrue(html.contains("<h1>A&lt;B&gt;</h1>"), html)
        XCTAssertTrue(html.contains("foo &amp; bar"), html)
    }

    func testOriginFormatsPathAndLine() {
        XCTAssertEqual(DocPage.origin(path: "/proj/src/util.rs", line: 4), "util.rs:4")
        XCTAssertEqual(DocPage.origin(path: "/proj/src/util.rs", line: 0), "util.rs")
        XCTAssertEqual(DocPage.origin(path: "", line: 4), "")
    }

    func testRideDocTargetKeepsPathWithColons() {
        XCTAssertEqual(DocLinkTarget.item(url: "ride-doc://Counter::new"), "Counter::new")
        XCTAssertNil(DocLinkTarget.item(url: "https://example.com"))
    }

    func testCatalogItemOpensDocsRs() {
        let url = DocExternal.url(name: "HashMap", crate: "std", path: "std::collections::HashMap")
        XCTAssertEqual(url?.absoluteString, "https://docs.rs/std/latest/std/?search=HashMap")
    }

    func testStdCppNameOpensCppreference() {
        let url = DocExternal.url(name: "vector", crate: "", path: "std::vector")
        XCTAssertEqual(url?.absoluteString, "https://en.cppreference.com/w/?search=std::vector")
    }

    func testCrateWinsOverStdPath() {
        let url = DocExternal.url(name: "Vec", crate: "alloc", path: "alloc::vec::Vec")
        XCTAssertEqual(url?.absoluteString, "https://docs.rs/alloc/latest/alloc/?search=Vec")
    }

    func testUnknownSymbolHasNoExternalUrl() {
        XCTAssertNil(DocExternal.url(name: "Counter", crate: "", path: "demo::Counter"))
    }
}
