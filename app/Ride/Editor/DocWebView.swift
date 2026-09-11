import AppKit
import WebKit

final class DocWebView: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let view: WKWebView
    var onLink: ((String) -> Void)?
    private var themeName = ""
    private var lastHTML = ""
    private var ready = false
    private var pending: String?

    override init() {
        let config = WKWebViewConfiguration()
        view = WKWebView(frame: .zero, configuration: config)
        super.init()
        let user = config.userContentController
        user.add(self, name: "rideDoc")
        user.addUserScript(WKUserScript(source: Self.clickScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
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
            view.loadHTMLString(PreviewTemplate.popup(theme), baseURL: nil)
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

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let href = message.body as? String, let target = DocLinkTarget.item(url: href) else {
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

    private static let clickScript = """
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
