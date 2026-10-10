import Foundation
import WebKit

final class HtmlSchemeHandler: NSObject, WKURLSchemeHandler {
    let root: URL
    let name: String
    private var page: String
    private var render: HtmlRender?
    private var halted = Set<ObjectIdentifier>()
    private let lock = NSLock()

    init(root: URL, name: String, page: String, render: HtmlRender? = nil) {
        self.root = root
        self.name = name
        self.page = page
        self.render = render
    }

    func update(page: String, render: HtmlRender?) {
        lock.lock()
        self.page = page
        self.render = render
        lock.unlock()
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        let url = task.request.url
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            let shot = self.snapshot()
            let payload = HtmlAsset.payload(root: self.root, name: self.name, page: shot.page, url: url, render: shot.render)
            self.deliver(task, payload)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        lock.lock()
        halted.insert(ObjectIdentifier(task))
        lock.unlock()
    }

    private func snapshot() -> (page: String, render: HtmlRender?) {
        lock.lock()
        defer { lock.unlock() }
        return (page, render)
    }

    private func halted(_ task: WKURLSchemeTask) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return halted.contains(ObjectIdentifier(task))
    }

    private func deliver(_ task: WKURLSchemeTask, _ payload: HtmlPayload) {
        guard !halted(task) else {
            return
        }
        switch payload {
        case .deny:
            task.didFailWithError(URLError(.resourceUnavailable))
        case let .bytes(data, mime, encoding):
            guard let url = task.request.url else {
                task.didFailWithError(URLError(.badURL))
                return
            }
            guard !halted(task) else {
                return
            }
            task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: encoding))
            guard !halted(task) else {
                return
            }
            task.didReceive(data)
            guard !halted(task) else {
                return
            }
            task.didFinish()
        }
    }
}
