import AppKit
import WebKit

final class HtmlWebCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var handler: HtmlSchemeHandler?
    var onFocus: () -> Void
    weak var host: HtmlFindHost?
    var document: BufferDocument
    var revision = ""
    var loadedName = ""
    var wasFocused = false
    private var active: WKNavigation?
    private var restoreID = 0
    private var restoring = false
    private var hold = false
    private var wanted = 0.0
    private var restoreTries = 0
    private var restorePending = false

    init(document: BufferDocument, onFocus: @escaping () -> Void) {
        self.document = document
        self.onFocus = onFocus
    }

    func load(_ web: WKWebView, named name: String) {
        guard let url = HtmlPage.url(named: name) else {
            return
        }
        wanted = document.htmlScrollY
        hold = wanted > 0
        restoring = hold
        restoreTries = 0
        restorePending = false
        restoreID += 1
        host?.onLayout = nil
        active = web.load(URLRequest(url: url))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == HtmlScroll.channel, host?.window != nil else {
            return
        }
        guard let y = HtmlScroll.offset(from: message.body) else {
            return
        }
        guard !restoring, !(y <= 0 && hold) else {
            return
        }
        hold = false
        document.htmlScrollY = y
        host?.noteScrolled()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard owns(navigation) else {
            return
        }
        active = nil
        guard restoring else {
            return
        }
        host?.onLayout = { [weak self] in
            self?.restore()
        }
        kick(0, restoreID)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(navigation)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(navigation)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor action: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        switch HtmlPage.decide(Self.kind(action.navigationType), action.request.url) {
        case .allow:
            if action.targetFrame == nil, let url = action.request.url {
                webView.load(URLRequest(url: url))
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        case let .open(url):
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        case .block:
            decisionHandler(.cancel)
        }
    }

    private func owns(_ navigation: WKNavigation?) -> Bool {
        guard let active, let navigation else {
            return false
        }
        return navigation === active
    }

    private func fail(_ navigation: WKNavigation?) {
        guard owns(navigation) else {
            return
        }
        active = nil
        stopRestore()
    }

    private func kick(_ tries: Int, _ id: Int) {
        guard restoring, id == restoreID else {
            return
        }
        guard tries < 8 else {
            stopRestore()
            return
        }
        restore()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.kick(tries + 1, id)
        }
    }

    private func restore() {
        guard restoring, !restorePending, let web = host?.web, web.bounds.height > 1 else {
            return
        }
        restorePending = true
        let wanted = self.wanted
        web.evaluateJavaScript(HtmlScroll.restore(wanted)) { [weak self] result, _ in
            self?.landed(wanted, (result as? NSNumber)?.doubleValue ?? 0)
        }
    }

    private func landed(_ wanted: Double, _ actual: Double) {
        restorePending = false
        guard restoring else {
            return
        }
        restoreTries += 1
        let reached = actual + 1 >= wanted
        let clamped = actual > 1 && restoreTries >= 3
        guard reached || clamped else {
            return
        }
        if actual > 0 {
            document.htmlScrollY = actual
            hold = false
        }
        stopRestore()
    }

    private func stopRestore() {
        restoring = false
        host?.onLayout = nil
    }

    private static func kind(_ type: WKNavigationType) -> HtmlNav {
        switch type {
        case .linkActivated:
            return .link
        case .formSubmitted, .formResubmitted:
            return .form
        default:
            return .load
        }
    }
}
