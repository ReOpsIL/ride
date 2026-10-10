import AppKit
import SwiftUI
import WebKit

struct HtmlWebView: NSViewRepresentable {
    @ObservedObject var document: BufferDocument
    let paneID: UUID
    let focused: Bool
    let revision: String
    let page: () -> String
    var renderSibling: HtmlRender? = nil
    let onFocus: () -> Void

    func makeCoordinator() -> HtmlWebCoordinator {
        HtmlWebCoordinator(document: document, onFocus: onFocus)
    }

    func makeNSView(context: Context) -> HtmlFindHost {
        let handler = HtmlSchemeHandler(root: root, name: name, page: page(), render: renderSibling)
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(handler, forURLScheme: HtmlPage.scheme)
        let user = config.userContentController
        user.addUserScript(WKUserScript(source: HtmlScroll.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        user.add(context.coordinator, name: HtmlScroll.channel)
        let web = HtmlSurface(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.setValue(false, forKey: "drawsBackground")
        let host = HtmlFindHost(web: web)
        host.onFocus = onFocus
        context.coordinator.handler = handler
        context.coordinator.host = host
        return host
    }

    func updateNSView(_ host: HtmlFindHost, context: Context) {
        let coordinator = context.coordinator
        coordinator.document = document
        coordinator.onFocus = onFocus
        coordinator.host = host
        host.onFocus = onFocus
        host.paneID = paneID
        claim(host, coordinator)
        guard let handler = coordinator.handler else {
            return
        }
        let name = self.name
        guard coordinator.revision != revision || coordinator.loadedName != name else {
            return
        }
        handler.update(page: page(), render: renderSibling)
        coordinator.revision = revision
        coordinator.loadedName = name
        coordinator.load(host.web, named: name)
    }

    static func dismantleNSView(_ host: HtmlFindHost, coordinator: HtmlWebCoordinator) {
        host.onLayout = nil
        host.web.configuration.userContentController.removeScriptMessageHandler(forName: HtmlScroll.channel)
    }

    private func claim(_ host: HtmlFindHost, _ coordinator: HtmlWebCoordinator) {
        let became = focused && !coordinator.wasFocused
        coordinator.wasFocused = focused
        guard became else {
            return
        }
        DispatchQueue.main.async {
            guard let window = host.window else {
                return
            }
            if HtmlFindHost.focused(in: window.firstResponder) === host {
                return
            }
            window.makeFirstResponder(host.web)
        }
    }

    private var name: String {
        document.fileURL?.lastPathComponent ?? ""
    }

    private var root: URL {
        document.fileURL?.deletingLastPathComponent() ?? URL(fileURLWithPath: "/")
    }
}
