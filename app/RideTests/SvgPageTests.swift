import WebKit
import XCTest

final class SvgPageTests: XCTestCase {
    func testMatchesSvgExtension() {
        XCTAssertTrue(SvgPage.matches(URL(fileURLWithPath: "/a/Icon.SVG")))
        XCTAssertFalse(SvgPage.matches(URL(fileURLWithPath: "/a/page.html")))
        XCTAssertFalse(SvgPage.matches(URL(fileURLWithPath: "/a/notes.md")))
        XCTAssertFalse(SvgPage.matches(URL(fileURLWithPath: "/a/dot.png")))
        XCTAssertFalse(SvgPage.matches(URL(fileURLWithPath: "/a/main.rs")))
        XCTAssertFalse(SvgPage.matches(nil))
    }

    func testDocumentRequestsAreNotImageLoads() {
        XCTAssertTrue(SvgPage.asDocument("text/html,application/xhtml+xml,*/*;q=0.8"))
        XCTAssertFalse(SvgPage.asDocument("image/svg+xml,image/*;q=0.8,*/*;q=0.5"))
        XCTAssertFalse(SvgPage.asDocument("*/*"))
        XCTAssertFalse(SvgPage.asDocument(nil))
    }

    func testDocumentDropsTheXmlPrologAndKeepsTheDrawing() {
        let source = """
        \u{feff}<?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
        <svg xmlns="http://www.w3.org/2000/svg" id="g"><text id="t">Mark</text></svg>
        """
        let html = SvgPage.document(source, background: "#010203", dark: true)
        XCTAssertFalse(html.contains("<?xml"))
        XCTAssertFalse(html.contains("<!DOCTYPE"))
        XCTAssertFalse(html.contains("\u{feff}"))
        XCTAssertTrue(html.contains("<svg xmlns=\"http://www.w3.org/2000/svg\" id=\"g\">"))
        XCTAssertTrue(html.contains(">Mark</text>"))
        XCTAssertTrue(html.contains("background:#010203"))
        XCTAssertTrue(html.contains("color-scheme:dark"))
        let stamped = HtmlPolicy.stamp(html)
        XCTAssertTrue(stamped.contains("Content-Security-Policy"))
        XCTAssertTrue(stamped.contains("default-src 'none'"))
    }

    func testBareSvgStaysTheDrawing() {
        let source = "<svg xmlns=\"http://www.w3.org/2000/svg\"><rect width=\"4\" height=\"4\"/></svg>"
        let html = SvgPage.document(source, background: "#fff", dark: false)
        XCTAssertTrue(html.contains(source))
        XCTAssertTrue(html.contains("color-scheme:light"))
    }

    func testOpenDrawingIsTheBufferAndImageSiblingsStayImages() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("<svg>DISK</svg>".utf8).write(to: root.appendingPathComponent("mark.svg"))
        let png = try XCTUnwrap(Data(base64Encoded: Self.pixel))
        try png.write(to: root.appendingPathComponent("dot.png"))
        let page = SvgPage.document("<svg id=\"g\">LIVE</svg>", background: "#fff", dark: false)
        let open = HtmlAsset.payload(root: root, name: "mark.svg", page: page, url: SvgPageURL.page("mark.svg"))
        guard case let .bytes(data, mime, encoding) = open else {
            return XCTFail("page")
        }
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(mime, "text/html")
        XCTAssertEqual(encoding, "utf-8")
        XCTAssertTrue(text.contains("LIVE"))
        XCTAssertTrue(text.contains("default-src 'none'"))
        XCTAssertFalse(text.contains("DISK"))
        let image = HtmlAsset.payload(root: root, name: "mark.svg", page: page, url: SvgPageURL.page("dot.png"))
        guard case let .bytes(imageData, imageMime, _) = image else {
            return XCTFail("png")
        }
        XCTAssertEqual(imageData, png)
        XCTAssertEqual(imageMime, "image/png")
    }

    func testLinkedSvgRendersAndEmbeddedSvgStaysAnImage() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("<svg id=\"other\">Other</svg>".utf8).write(to: root.appendingPathComponent("other.svg"))
        let page = SvgPage.document("<svg id=\"g\">LIVE</svg>", background: "#fff", dark: false)
        let linked = HtmlAsset.payload(
            root: root,
            name: "mark.svg",
            page: page,
            url: SvgPageURL.page("other.svg"),
            render: { name, data in
                guard name == "other.svg", let text = String(data: data, encoding: .utf8) else {
                    return nil
                }
                return SvgPage.document(text, background: "#abc", dark: true)
            },
            accept: "text/html"
        )
        guard case let .bytes(linkedData, linkedMime, _) = linked else {
            return XCTFail("linked")
        }
        let linkedText = String(decoding: linkedData, as: UTF8.self)
        XCTAssertEqual(linkedMime, "text/html")
        XCTAssertTrue(linkedText.contains("Other"))
        XCTAssertTrue(linkedText.contains("background:#abc"))
        XCTAssertTrue(linkedText.contains("Content-Security-Policy"))
        let embedded = HtmlAsset.payload(
            root: root,
            name: "mark.svg",
            page: page,
            url: SvgPageURL.page("other.svg"),
            render: { _, _ in "<p>WRAPPED</p>" },
            accept: "image/svg+xml"
        )
        guard case let .bytes(embeddedData, embeddedMime, _) = embedded else {
            return XCTFail("embedded")
        }
        XCTAssertEqual(String(decoding: embeddedData, as: UTF8.self), "<svg id=\"other\">Other</svg>")
        XCTAssertEqual(embeddedMime, "image/svg+xml")
    }

    func testWebViewRendersTheBufferAndBlocksTheNetwork() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let png = try XCTUnwrap(Data(base64Encoded: Self.pixel))
        try png.write(to: root.appendingPathComponent("dot.png"))
        let drawing = """
        <svg xmlns="http://www.w3.org/2000/svg" width="80" height="40">\
        <text id="t" x="4" y="24">Mark</text>\
        <image id="local" href="dot.png" width="1" height="1"/>\
        </svg>
        """
        let page = SvgPage.document(drawing, background: "#010203", dark: true)
            .replacingOccurrences(of: "</body>", with: "<img id=\"remote\" src=\"https://example.com/a.png\"></body>")
        let handler = HtmlSchemeHandler(root: root, name: "mark.svg", page: page)
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(handler, forURLScheme: HtmlPage.scheme)
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 240), configuration: config)
        let loaded = expectation(description: "load")
        let nav = SvgLoadWait(done: loaded)
        view.navigationDelegate = nav
        view.load(URLRequest(url: try XCTUnwrap(SvgPageURL.page("mark.svg"))))
        wait(for: [loaded], timeout: 5)
        XCTAssertNil(nav.error)
        XCTAssertEqual(try script(view, "document.getElementById('t').textContent") as? String, "Mark")
        XCTAssertEqual(try script(view, "getComputedStyle(document.body).backgroundColor") as? String, "rgb(1, 2, 3)")
        let policy = try script(view, "document.querySelector('meta[http-equiv=\"Content-Security-Policy\"]').content") as? String
        XCTAssertTrue(policy?.contains("default-src 'none'") == true)
        XCTAssertEqual(number(try script(view, "document.getElementById('remote').naturalWidth")), 0)
    }

    private func number(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    private func script(_ view: WKWebView, _ source: String) throws -> Any? {
        let done = expectation(description: source)
        var value: Any?
        var failure: Error?
        view.evaluateJavaScript(source) { result, error in
            value = result
            failure = error
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        if let failure {
            throw failure
        }
        return value
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.standardizedFileURL.resolvingSymlinksInPath()
    }

    private static let pixel = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
}

private enum SvgPageURL {
    static func page(_ name: String) -> URL? {
        HtmlPage.url(named: name)
    }
}

private final class SvgLoadWait: NSObject, WKNavigationDelegate {
    var done: XCTestExpectation
    var error: Error?

    init(done: XCTestExpectation) {
        self.done = done
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        done.fulfill()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.error = error
        done.fulfill()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.error = error
        done.fulfill()
    }
}
