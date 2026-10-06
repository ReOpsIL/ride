import AppKit
import WebKit

final class AIChatPage: NSObject, WKNavigationDelegate {
    private static let baseURL = URL(string: "https://ride.invalid/") ?? URL(fileURLWithPath: "/")
    let view: WKWebView
    var onInsert: ((String) -> Void)?
    var onOpen: ((String, Int) -> Void)?
    private let proxy: AIChatScriptProxy
    private var themeName = ""
    private var ready = false
    private var threadID: UUID?
    private var shown: [UUID: Int] = [:]
    private var queued: AIChatThread?

    override init() {
        let proxy = AIChatScriptProxy()
        let config = WKWebViewConfiguration()
        config.userContentController.add(proxy, name: "rideChat")
        config.userContentController.addUserScript(
            WKUserScript(source: AIChatTemplate.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        self.proxy = proxy
        view = WKWebView(frame: .zero, configuration: config)
        super.init()
        proxy.owner = self
        view.navigationDelegate = self
        view.setValue(false, forKey: "drawsBackground")
    }

    deinit {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "rideChat")
    }

    func show(_ thread: AIChatThread?) {
        let theme = ThemeStore.shared.theme
        if themeName != theme.name {
            themeName = theme.name
            ready = false
            reset()
            queued = thread
            view.loadHTMLString(AIChatTemplate.page(theme), baseURL: Self.baseURL)
            return
        }
        guard ready else {
            queued = thread
            return
        }
        push(thread)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        let thread = queued
        queued = nil
        push(thread)
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
        if url.scheme == "http" || url.scheme == "https" {
            NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    fileprivate func receive(action: String, text: String) {
        switch action {
        case "copy":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case "insert":
            onInsert?(text)
        case "open":
            if let location = AIChatLocation(text) {
                onOpen?(location.path, location.line)
            }
        default:
            break
        }
    }

    private func reset() {
        threadID = nil
        shown = [:]
    }

    private func push(_ thread: AIChatThread?) {
        if thread?.id != threadID {
            reset()
            threadID = thread?.id
            let empty = thread?.messages.isEmpty ?? true
            run("rideClear(\(Self.json(empty ? Self.placeholder : "")))")
        }
        guard let thread else {
            return
        }
        let render: (String) -> String = { RideEngineClient.shared.engine?.renderMarkdown(text: $0) ?? AIChatHTML.escape($0) }
        for message in thread.messages {
            let key = Self.key(message)
            guard shown[message.id] != key else {
                continue
            }
            let first = shown.isEmpty
            shown[message.id] = key
            let html = AIChatHTML.message(message, render: render)
            run("rideUpsert(\(Self.json(message.id.uuidString)),\(Self.json(html)),\(first || message.role == .user))")
        }
    }

    private func run(_ script: String) {
        view.evaluateJavaScript(script)
    }

    private static let placeholder = "<p class=\"empty\">Ask about the open project. ⌘L adds the selection, Code › Explain explains it.</p>"

    private static func key(_ message: AIChatMessage) -> Int {
        var hasher = Hasher()
        hasher.combine(message.text)
        hasher.combine(message.streaming)
        hasher.combine(message.error)
        return hasher.finalize()
    }

    private static func json(_ text: String) -> String {
        (try? JSONEncoder().encode(text)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }
}

private final class AIChatScriptProxy: NSObject, WKScriptMessageHandler {
    weak var owner: AIChatPage?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let action = body["action"] as? String else {
            return
        }
        owner?.receive(action: action, text: body["text"] as? String ?? "")
    }
}
