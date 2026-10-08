import Foundation
import WebKit

final class HtmlSchemeHandler: NSObject, WKURLSchemeHandler {
    let root: URL
    let name: String
    private var page: String
    private var halted = Set<ObjectIdentifier>()
    private let lock = NSLock()

    init(root: URL, name: String, page: String) {
        self.root = root
        self.name = name
        self.page = page
    }

    func update(page: String) {
        lock.lock()
        self.page = page
        lock.unlock()
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        let payload = HtmlAsset.payload(root: root, name: name, page: copyPage(), url: task.request.url)
        DispatchQueue.main.async { [weak self] in
            self?.deliver(task, payload)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        lock.lock()
        halted.insert(ObjectIdentifier(task))
        lock.unlock()
    }

    private func copyPage() -> String {
        lock.lock()
        defer { lock.unlock() }
        return page
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
