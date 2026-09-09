import SwiftUI
import WebKit

struct MarkdownPreview: NSViewRepresentable {
    @ObservedObject var model: PreviewModel
    @ObservedObject private var ts = ThemeStore.shared

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        context.coordinator.load(view, theme: ts.theme, html: model.html)
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.themeName != ts.theme.name {
            coordinator.load(view, theme: ts.theme, html: model.html)
            return
        }
        if coordinator.lastHTML != model.html {
            coordinator.push(view, html: model.html)
        }
        if coordinator.lastLine != model.visibleLine {
            coordinator.lastLine = model.visibleLine
            if coordinator.ready, model.visibleLine > 1 || coordinator.lastLine > 1 {
                view.evaluateJavaScript("scrollToLine(\(model.visibleLine))")
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var themeName = ""
        var lastHTML = ""
        var lastLine = 0
        var ready = false
        var pendingHTML: String?

        func load(_ view: WKWebView, theme: Theme, html: String) {
            themeName = theme.name
            ready = false
            pendingHTML = html
            lastHTML = ""
            view.loadHTMLString(PreviewTemplate.page(theme), baseURL: nil)
        }

        func push(_ view: WKWebView, html: String) {
            lastHTML = html
            guard ready else {
                pendingHTML = html
                return
            }
            let json = (try? JSONEncoder().encode(html)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
            view.evaluateJavaScript("setBody(\(json))")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            if let html = pendingHTML {
                pendingHTML = nil
                push(webView, html: html)
            }
            if lastLine > 1 {
                webView.evaluateJavaScript("scrollToLine(\(lastLine))")
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor action: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if action.navigationType == .linkActivated, let url = action.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
