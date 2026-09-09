import AppKit
import SwiftUI

struct SplitPositioner: NSViewRepresentable {
    let position: Double
    var fromEnd = false

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            apply(to: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func apply(to view: NSView) {
        var candidate = view.superview
        while let current = candidate, !(current is NSSplitView) {
            candidate = current.superview
        }
        guard let split = candidate as? NSSplitView, split.arrangedSubviews.count > 1 else {
            return
        }
        let total = split.isVertical ? split.bounds.width : split.bounds.height
        let target = fromEnd ? max(total - position, 0) : position
        split.setPosition(target, ofDividerAt: split.arrangedSubviews.count - 2)
        DividerGrip.install(in: split)
    }
}
