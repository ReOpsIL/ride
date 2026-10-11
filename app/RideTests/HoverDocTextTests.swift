import XCTest

final class HoverDocTextTests: XCTestCase {
    func testPlainKeepsLaterSectionsAndCode() {
        let html = """
        <span class="ride-line" data-line="1"></span>
        <p>Reads the file.</p>
        <span class="ride-line" data-line="3"></span>
        <h1>Errors</h1>
        <span class="ride-line" data-line="5"></span>
        <p>Missing path.</p>
        <span class="ride-line" data-line="7"></span>
        <pre><code class="language-rust"><span class="tk-function">read_to_string</span>(<span class="tk-string">&quot;a.txt&quot;</span>)<span class="tk-punctuation">;</span>
        </code></pre>
        """
        XCTAssertEqual(
            HoverDocText.plain(html),
            """
            Reads the file.

            Errors

            Missing path.

            read_to_string("a.txt");
            """
        )
    }

    func testPlainKeepsIndentedExampleLines() {
        let html = "<pre><code>fn main() {\n    let n = 1;\n}</code></pre>"
        XCTAssertEqual(HoverDocText.plain(html), "fn main() {\n    let n = 1;\n}")
    }

    func testPlainTurnsListsAndLinksIntoText() {
        let html = "<p>See <a href=\"ride-doc://File::open\"><code>File::open</code></a>.</p><ul><li>One</li><li>Two</li></ul>"
        XCTAssertEqual(
            HoverDocText.plain(html),
            """
            See File::open.
            • One
            • Two
            """
        )
    }

    func testPlainOfEmptyIsEmpty() {
        XCTAssertEqual(HoverDocText.plain(""), "")
        XCTAssertEqual(HoverDocText.plain("<span class=\"ride-line\"></span>"), "")
    }
}
