import AppKit
import ObjectiveC

final class ViewportWatch {
    private typealias DidLayout = @convention(c) (AnyObject, Selector, AnyObject) -> Void
    private static let selector = NSSelectorFromString("textViewportLayoutControllerDidLayout:")
    private static var installed = false
    private static weak var current: ViewportWatch?

    private weak var view: RideTextView?
    private(set) var failures: [String] = []
    private(set) var layouts = 0
    var label = ""

    init(view: RideTextView) {
        self.view = view
        Self.install()
        Self.current = self
    }

    private static func install() {
        guard !installed, let method = class_getInstanceMethod(NSTextView.self, selector) else {
            return
        }
        installed = true
        let original = unsafeBitCast(method_getImplementation(method), to: DidLayout.self)
        let block: @convention(block) (AnyObject, AnyObject) -> Void = { object, controller in
            original(object, selector, controller)
            if let view = object as? RideTextView, let controller = controller as? NSTextViewportLayoutController {
                current?.didLayout(view, controller)
            }
        }
        class_replaceMethod(RideTextView.self, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method))
    }

    private func didLayout(_ view: RideTextView, _ controller: NSTextViewportLayoutController) {
        guard view === self.view, let tlm = view.textLayoutManager, let range = controller.viewportRange else {
            return
        }
        layouts += 1
        var laidOut: CGFloat = 0
        tlm.enumerateTextLayoutFragments(from: range.location, options: []) { fragment in
            laidOut = max(laidOut, fragment.layoutFragmentFrame.maxY)
            return fragment.rangeInElement.endLocation.compare(range.endLocation) == .orderedAscending
        }
        let wanted = min(controller.viewportBounds.maxY, tlm.usageBoundsForTextContainer.maxY)
        if laidOut + 0.5 < wanted, failures.count < 20 {
            failures.append("\(label) laid out to \(Int(laidOut)) of \(Int(wanted))")
        }
    }
}
