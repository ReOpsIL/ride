import WebKit
import XCTest

final class HtmlScrollTests: XCTestCase {
    private var windows: [NSWindow] = []

    func testOffsetReadsPostedNumbers() {
        XCTAssertEqual(HtmlScroll.offset(from: NSNumber(value: 12.5)), 12.5)
        XCTAssertEqual(HtmlScroll.offset(from: NSNumber(value: 4)), 4)
        XCTAssertEqual(HtmlScroll.offset(from: 9.25), 9.25)
        XCTAssertNil(HtmlScroll.offset(from: "no"))
    }

    func testSystemFindBarBecomesVisible() throws {
        let web = HtmlSurface(frame: NSRect(x: 0, y: 0, width: 420, height: 280), configuration: WKWebViewConfiguration())
        let host = HtmlFindHost(web: web)
        host.frame = web.frame
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.setFrameOrigin(NSPoint(x: -4000, y: -4000))
        window.contentView = host
        windows.append(window)
        window.layoutIfNeeded()
        host.layoutSubtreeIfNeeded()
        host.toggleFind(replace: false)
        host.layoutSubtreeIfNeeded()
        let bar = try XCTUnwrap(host.findBarView)
        XCTAssertTrue(host.isFindBarVisible)
        XCTAssertFalse(bar.isHidden)
        XCTAssertGreaterThan(bar.frame.height, 1)
        XCTAssertLessThan(host.contentView.frame.height, host.bounds.height - 1)
        window.makeKey()
        XCTAssertTrue(window.makeFirstResponder(host.web))
        let event = try XCTUnwrap(findEvent(in: window))
        window.sendEvent(event)
        let responder = window.firstResponder.map { String(describing: type(of: $0)) } ?? "nil"
        XCTAssertFalse(host.isFindBarVisible, "responder \(responder)")
        window.sendEvent(event)
        XCTAssertTrue(host.isFindBarVisible, "responder \(responder)")
    }

    func testRestoreScriptUsesTheOffset() {
        XCTAssertTrue(HtmlScroll.restore(1800).contains("1800"))
        XCTAssertTrue(HtmlScroll.restore(-5).contains("scrollTo"))
        XCTAssertFalse(HtmlScroll.restore(-5).contains("-5"))
        XCTAssertTrue(HtmlScroll.script.contains(HtmlScroll.channel))
        XCTAssertTrue(HtmlScroll.script.contains("pagehide"))
    }

    func testNewWebViewKeepsVerticalScroll() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let page = "<!doctype html><head></head><body style=\"margin:0\"><div style=\"height:6000px\"></div></body>"
        let catcher = HtmlScrollCatch()
        let reported = expectation(description: "scroll")
        catcher.report = reported
        let first = try load(root: root, page: page, catcher: catcher)
        let y = try number(script(first, HtmlScroll.restore(2400)))
        XCTAssertGreaterThan(y, 2000)
        wait(for: [reported], timeout: 5)
        let second = try load(root: root, page: page, catcher: nil)
        let restored = try number(script(second, HtmlScroll.restore(y)))
        XCTAssertGreaterThan(restored, 2000)
    }

    private func findEvent(in window: NSWindow) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "f",
            charactersIgnoringModifiers: "f",
            isARepeat: false,
            keyCode: 3
        )
    }

    private func load(root: URL, page: String, catcher: HtmlScrollCatch?) throws -> WKWebView {
        let handler = HtmlSchemeHandler(root: root, name: "index.html", page: page)
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(handler, forURLScheme: HtmlPage.scheme)
        if let catcher {
            let user = config.userContentController
            user.add(catcher, name: HtmlScroll.channel)
            user.addUserScript(WKUserScript(source: HtmlScroll.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 320, height: 180), configuration: config)
        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
        window.contentView = view
        windows.append(window)
        let loaded = expectation(description: "load")
        let nav = HtmlScrollLoad(done: loaded)
        view.navigationDelegate = nav
        nav.navigation = view.load(URLRequest(url: try XCTUnwrap(HtmlPage.url(named: "index.html"))))
        wait(for: [loaded], timeout: 5)
        XCTAssertNil(nav.error)
        XCTAssertTrue(nav.matched)
        return view
    }

    private func script(_ view: WKWebView, _ source: String) throws -> Any? {
        let done = expectation(description: "script")
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

    private func number(_ value: Any?) throws -> Double {
        try XCTUnwrap((value as? NSNumber)?.doubleValue)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.standardizedFileURL.resolvingSymlinksInPath()
    }
}

private final class HtmlScrollCatch: NSObject, WKScriptMessageHandler {
    var report: XCTestExpectation?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let y = HtmlScroll.offset(from: message.body), y > 2000 else {
            return
        }
        report?.fulfill()
        report = nil
    }
}

private final class HtmlScrollLoad: NSObject, WKNavigationDelegate {
    var done: XCTestExpectation
    var error: Error?
    var navigation: WKNavigation?
    var matched = false

    init(done: XCTestExpectation) {
        self.done = done
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        matched = navigation === self.navigation
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
