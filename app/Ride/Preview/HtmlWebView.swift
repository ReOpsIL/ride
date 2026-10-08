import AppKit
import SwiftUI
import WebKit

struct HtmlWebView: NSViewRepresentable {
    @ObservedObject var document: BufferDocument
    let focused: Bool
    let onFocus: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFocus: onFocus)
    }

    func makeNSView(context: Context) -> WKWebView {
        let handler = HtmlSchemeHandler(root: root, name: name, page: document.text)
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(handler, forURLScheme: HtmlPage.scheme)
        let view = HtmlSurface(frame: .zero, configuration: config)
        view.onFocus = onFocus
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        context.coordinator.handler = handler
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onFocus = onFocus
        (view as? HtmlSurface)?.onFocus = onFocus
        guard let handler = coordinator.handler else {
            return
        }
        let name = self.name
        if coordinator.generation != document.htmlGeneration || coordinator.loadedName != name {
            handler.update(page: document.text)
            coordinator.generation = document.htmlGeneration
            coordinator.loadedName = name
            coordinator.load(view, named: name)
            claim(view)
        }
    }

    private var name: String {
        document.fileURL?.lastPathComponent ?? ""
    }

    private var root: URL {
        document.fileURL?.deletingLastPathComponent() ?? URL(fileURLWithPath: "/")
    }

    private func claim(_ view: WKWebView) {
        guard focused else {
            return
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
    }
}

extension HtmlWebView {
    final class Coordinator: NSObject, WKNavigationDelegate {
        var handler: HtmlSchemeHandler?
        var onFocus: () -> Void
        var generation = -1
        var loadedName = ""

        init(onFocus: @escaping () -> Void) {
            self.onFocus = onFocus
        }

        func load(_ view: WKWebView, named name: String) {
            guard let url = HtmlPage.url(named: name) else {
                return
            }
            view.load(URLRequest(url: url))
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
}

private final class HtmlSurface: WKWebView {
    var onFocus: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onFocus?()
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        onFocus?()
        let became = super.becomeFirstResponder()
        return became
    }
}
