import AppKit
import WebKit

final class HtmlSurface: WKWebView {
    var onFocus: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if let host = HtmlFindHost.focused(in: self), host.performFindKey(event) {
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let host = HtmlFindHost.focused(in: self), host.performFindKey(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        onFocus?()
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        onFocus?()
        return super.becomeFirstResponder()
    }
}
