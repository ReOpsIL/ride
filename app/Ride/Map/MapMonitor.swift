import AppKit
import SwiftUI

struct MapMonitor: NSViewRepresentable {
    let enabled: Bool
    let onScroll: (CGFloat, CGPoint) -> Void
    let onMagnify: (CGFloat, CGPoint) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = MapMonitorView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? MapMonitorView else { return }
        update(view)
    }

    private func update(_ view: MapMonitorView) {
        view.enabled = enabled
        view.onScroll = onScroll
        view.onMagnify = onMagnify
    }
}

final class MapMonitorView: NSView {
    var enabled = false
    var onScroll: ((CGFloat, CGPoint) -> Void)?
    var onMagnify: ((CGFloat, CGPoint) -> Void)?
    private var monitor: Any?

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            uninstall()
        } else {
            install()
        }
    }

    private func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard enabled, event.window === window, let point = localPoint(for: event) else { return event }
        switch event.type {
        case .scrollWheel:
            onScroll?(event.scrollingDeltaY, point)
            return nil
        case .magnify:
            onMagnify?(event.magnification, point)
            return nil
        default:
            return event
        }
    }

    private func localPoint(for event: NSEvent) -> CGPoint? {
        let point = convert(event.locationInWindow, from: nil)
        return bounds.contains(point) ? point : nil
    }

    private func uninstall() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }
}
