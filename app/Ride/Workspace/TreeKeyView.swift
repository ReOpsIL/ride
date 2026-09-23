import AppKit
import SwiftUI

enum TreeKeyFocus {
    static weak var view: TreeKeyView?
    static var url: URL?

    static func select(_ url: URL) {
        self.url = url
        DispatchQueue.main.async {
            view?.window?.makeFirstResponder(view)
        }
    }
}

struct TreeKeyHost: NSViewRepresentable {
    func makeNSView(context: Context) -> TreeKeyView {
        let view = TreeKeyView()
        TreeKeyFocus.view = view
        return view
    }

    func updateNSView(_ view: TreeKeyView, context: Context) {
        TreeKeyFocus.view = view
    }
}

final class TreeKeyView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            TreeKeyFocus.view = self
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func keyDown(with event: NSEvent) {
        if TreeActions.handleKey(keyCode: event.keyCode, url: TreeKeyFocus.url) {
            return
        }
        super.keyDown(with: event)
    }
}
