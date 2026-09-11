import AppKit
import WebKit

final class DocWebView: NSObject, WKNavigationDelegate {
    private static let baseURL = URL(string: "https://ride.invalid/")!
    let view: WKWebView
    var onLink: ((String) -> Void)?
    private let proxy: DocScriptProxy
    private var themeName = ""
    private var lastHTML = ""
    private var ready = false
    private var pending: String?

    override init() {
        let proxy = DocScriptProxy()
        let config = WKWebViewConfiguration()
        let user = config.userContentController
        user.add(proxy, name: "rideDoc")
        user.addUserScript(WKUserScript(source: Self.pageScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        self.proxy = proxy
        view = WKWebView(frame: .zero, configuration: config)
        super.init()
        proxy.owner = self
        view.navigationDelegate = self
        view.setValue(false, forKey: "drawsBackground")
    }

    deinit {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "rideDoc")
    }

    func show(html: String) {
        let theme = ThemeStore.shared.theme
        if themeName != theme.name {
            themeName = theme.name
            ready = false
            pending = html
            lastHTML = ""
            view.loadHTMLString(PreviewTemplate.popup(theme), baseURL: Self.baseURL)
            return
        }
        push(html)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        if let html = pending {
            pending = nil
            push(html)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor action: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard action.navigationType == .linkActivated, let url = action.request.url else {
            decisionHandler(.allow)
            return
        }
        if let target = DocLinkTarget.item(url: url.absoluteString) {
            onLink?(target)
            decisionHandler(.cancel)
            return
        }
        if url.scheme == "http" || url.scheme == "https" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    fileprivate func receiveLink(_ href: String) {
        guard let target = DocLinkTarget.item(url: href) else {
            return
        }
        onLink?(target)
    }

    private func push(_ html: String) {
        lastHTML = html
        guard ready else {
            pending = html
            return
        }
        let json = (try? JSONEncoder().encode(html)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        view.evaluateJavaScript("setBody(\(json))")
    }

    private static let pageScript = """
    function setBody(h){var m=document.getElementById('main');if(m)m.innerHTML=h;}
    document.addEventListener('click', function(e) {
      var a = e.target.closest('a');
      if (!a) return;
      var href = a.getAttribute('href') || '';
      if (href.indexOf('ride-doc:') === 0) {
        e.preventDefault();
        e.stopPropagation();
        window.webkit.messageHandlers.rideDoc.postMessage(href);
      }
    }, true);
    """
}

private final class DocScriptProxy: NSObject, WKScriptMessageHandler {
    weak var owner: DocWebView?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let href = message.body as? String else {
            return
        }
        owner?.receiveLink(href)
    }
}
