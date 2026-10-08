import WebKit
import XCTest

final class HtmlPageTests: XCTestCase {
    func testMatchesHtmlExtensions() {
        XCTAssertTrue(HtmlPage.matches(URL(fileURLWithPath: "/a/Index.HTML")))
        XCTAssertTrue(HtmlPage.matches(URL(fileURLWithPath: "/a/page.htm")))
        XCTAssertFalse(HtmlPage.matches(URL(fileURLWithPath: "/a/notes.md")))
        XCTAssertFalse(HtmlPage.matches(URL(fileURLWithPath: "/a/main.rs")))
        XCTAssertFalse(HtmlPage.matches(nil))
    }

    func testPageURLStaysOnTheLocalHost() {
        let url = HtmlPage.url(named: "my page.html")
        XCTAssertEqual(url?.scheme, "ride-html")
        XCTAssertEqual(url?.host, "local")
        XCTAssertEqual(url?.path, "/my page.html")
        XCTAssertNil(HtmlPage.url(named: ""))
        XCTAssertNil(HtmlPage.url(named: "dir/index.html"))
    }

    func testNavigationKeepsLocalPagesAndOpensWebLinks() {
        let page = HtmlPage.url(named: "index.html")
        XCTAssertEqual(HtmlPage.decide(.load, page), .allow)
        XCTAssertEqual(HtmlPage.decide(.link, page), .allow)
        XCTAssertEqual(HtmlPage.decide(.form, page), .block)
        let web = URL(string: "https://example.com/docs")!
        XCTAssertEqual(HtmlPage.decide(.link, web), .open(web))
        XCTAssertEqual(HtmlPage.decide(.load, web), .block)
        XCTAssertEqual(HtmlPage.decide(.link, URL(string: "javascript:alert(1)")), .block)
        XCTAssertEqual(HtmlPage.decide(.link, URL(string: "file:///etc/passwd")), .block)
        XCTAssertEqual(HtmlPage.decide(.link, nil), .block)
    }

    func testLexicalPathsCannotLeaveTheFolder() {
        XCTAssertEqual(HtmlAsset.lexical("/css/../a.css"), "a.css")
        XCTAssertEqual(HtmlAsset.lexical("./img/logo.png"), "img/logo.png")
        XCTAssertNil(HtmlAsset.lexical("../secret"))
        XCTAssertNil(HtmlAsset.lexical("/../../etc/passwd"))
        XCTAssertNil(HtmlAsset.lexical("/"))
        XCTAssertNil(HtmlAsset.lexical("a/\0/b"))
    }

    func testFilesStayInsideTheFolder() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let css = HtmlAsset.file(root: root, relative: "css/site.css")
        XCTAssertEqual(css?.path, root.appendingPathComponent("css/site.css").path)
        XCTAssertNil(HtmlAsset.file(root: root, relative: "../secret"))
        let outside = root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
        try Data("x".utf8).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("leak.txt"), withDestinationURL: outside)
        XCTAssertNil(HtmlAsset.file(root: root, relative: "leak.txt"))
    }

    func testOpenPageIsTheBufferAndSiblingsComeFromDisk() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("DISK".utf8).write(to: root.appendingPathComponent("index.html"))
        try Data("body{}".utf8).write(to: root.appendingPathComponent("a.css"))
        let page = HtmlAsset.payload(root: root, name: "index.html", page: "<header>T</header><p>LIVE</p>", url: HtmlPage.url(named: "index.html"))
        guard case let .bytes(data, mime, encoding) = page else {
            return XCTFail("page")
        }
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(mime, "text/html")
        XCTAssertEqual(encoding, "utf-8")
        XCTAssertTrue(text.hasPrefix("<head>"))
        XCTAssertTrue(text.contains("LIVE"))
        XCTAssertTrue(text.contains("<header>T</header>"))
        XCTAssertFalse(text.contains("DISK"))
        XCTAssertTrue(text.contains("default-src 'none'"))
        let css = HtmlAsset.payload(root: root, name: "index.html", page: "LIVE", url: URL(string: "ride-html://local/a.css"))
        guard case let .bytes(cssData, cssMime, _) = css else {
            return XCTFail("css")
        }
        XCTAssertEqual(String(decoding: cssData, as: UTF8.self), "body{}")
        XCTAssertEqual(cssMime, "text/css")
        XCTAssertEqual(HtmlAsset.payload(root: root, name: "index.html", page: "LIVE", url: URL(string: "https://example.com/a.css")), .deny)
    }

    func testHeadStampSkipsHeaderElements() {
        let stamped = HtmlPolicy.stamp("<HEAD lang=\"en\"><title>A</title></head><p>Hi</p>")
        XCTAssertTrue(stamped.contains("<HEAD lang=\"en\"><meta http-equiv=\"Content-Security-Policy\""))
        XCTAssertFalse(stamped.hasPrefix("<head>"))
    }

    func testWebViewRendersTheBufferAndLocalCss() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("p{color:rgb(1, 2, 3)}".utf8).write(to: root.appendingPathComponent("a.css"))
        let page = "<!doctype html><head></head><body><p id=\"t\">Hello</p><img id=\"i\" src=\"https://example.com/a.png\"></body>"
        let handler = HtmlSchemeHandler(root: root, name: "index.html", page: page)
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(handler, forURLScheme: HtmlPage.scheme)
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 240), configuration: config)
        let loaded = expectation(description: "load")
        let nav = HtmlLoadWait(done: loaded)
        view.navigationDelegate = nav
        view.load(URLRequest(url: try XCTUnwrap(HtmlPage.url(named: "index.html"))))
        wait(for: [loaded], timeout: 5)
        XCTAssertNil(nav.error)
        XCTAssertEqual(try script(view, "document.getElementById('t').textContent") as? String, "Hello")
        XCTAssertEqual(number(try script(view, "document.getElementById('i').naturalWidth")), 0)
        let linked = "<!doctype html><head><link rel=\"stylesheet\" href=\"a.css\"></head><body><p id=\"t\">Styled</p></body>"
        let again = expectation(description: "reload")
        nav.done = again
        handler.update(page: linked)
        view.reload()
        wait(for: [again], timeout: 5)
        XCTAssertNil(nav.error)
        XCTAssertEqual(try script(view, "getComputedStyle(document.getElementById('t')).color") as? String, "rgb(1, 2, 3)")
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

    private func number(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.standardizedFileURL.resolvingSymlinksInPath()
    }
}

private final class HtmlLoadWait: NSObject, WKNavigationDelegate {
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
