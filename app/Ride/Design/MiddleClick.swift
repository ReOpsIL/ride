import AppKit
import SwiftUI

struct MiddleClick: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> MiddleClickView {
        let view = MiddleClickView()
        view.action = action
        return view
    }

    func updateNSView(_ view: MiddleClickView, context: Context) {
        view.action = action
    }
}

final class MiddleClickView: NSView {
    var action: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let type = NSApp.currentEvent?.type, type == .otherMouseDown || type == .otherMouseUp else {
            return nil
        }
        return super.hitTest(point)
    }

    override func otherMouseUp(with event: NSEvent) {
        if event.buttonNumber == 2 {
            action?()
        }
    }
}
