import AppKit
import SwiftUI

enum TreeKeyFocus {
    static weak var view: TreeKeyView?

    static func focus() {
        DispatchQueue.main.async {
            view?.window?.makeFirstResponder(view)
        }
    }
}

struct TreeKeyHost: NSViewRepresentable {
    @EnvironmentObject private var state: AppState

    func makeNSView(context: Context) -> TreeKeyView {
        let view = TreeKeyView()
        view.state = state
        TreeKeyFocus.view = view
        return view
    }

    func updateNSView(_ view: TreeKeyView, context: Context) {
        view.state = state
        TreeKeyFocus.view = view
    }
}

final class TreeKeyView: NSView {
    weak var state: AppState?

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
        if state?.handleTreeKey(keyCode: event.keyCode, modifiers: KeyModifiers(flags: event.modifierFlags)) == true {
            return
        }
        super.keyDown(with: event)
    }
}
