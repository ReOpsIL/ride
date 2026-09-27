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
        guard let split = Self.enclosingSplit(of: view),
              let index = split.arrangedSubviews.firstIndex(where: { view.isDescendant(of: $0) })
        else {
            return
        }
        let extents = split.arrangedSubviews.map { split.isVertical ? $0.frame.width : $0.frame.height }
        let total = split.isVertical ? split.bounds.width : split.bounds.height
        guard let placement = SplitDividerPlacement.divider(
            for: index,
            extents: extents,
            divider: split.dividerThickness,
            total: total,
            size: position,
            fromEnd: fromEnd
        ) else {
            return
        }
        split.setPosition(placement.position, ofDividerAt: placement.index)
        DividerGrip.install(in: split)
    }

    private static func enclosingSplit(of view: NSView) -> NSSplitView? {
        var candidate = view.superview
        while let current = candidate, !(current is NSSplitView) {
            candidate = current.superview
        }
        guard let split = candidate as? NSSplitView, split.arrangedSubviews.count > 1 else {
            return nil
        }
        return split
    }
}
