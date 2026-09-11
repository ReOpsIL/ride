import AppKit

final class HoverController {
    static let shared = HoverController()
    static let delay = 0.5
    static let throttle = 0.15
    private let panel = HoverPanel()
    private var lifecycle: CompletionLifecycle?
    private var timer: DispatchWorkItem?
    private var lastFire = Date.distantPast
    private var word: NSRange?
    private var shown: NSRange?
    private weak var view: RideTextView?

    private init() {
        lifecycle = CompletionLifecycle(panel: panel.panel) { [weak self] in
            self?.hide()
        }
        panel.onClick = { [weak self] in
            _ = self?.upgradeIfVisible()
        }
    }

    func upgradeIfVisible() -> Bool {
        guard panel.isVisible, let view, let shown else {
            return false
        }
        let loc = shown.location
        hide()
        EditorPanes.shared.host(for: view)?.docs.show(utf16: loc, in: view)
        return true
    }

    func mouseMoved(view: RideTextView, event: NSEvent) {
        let point = view.convert(event.locationInWindow, from: nil)
        let index = view.characterIndexForInsertion(at: point)
        guard let range = IdentifierRange.at(view.string as NSString, index: index) else {
            hide()
            return
        }
        if range == shown, panel.isVisible {
            return
        }
        if range == word {
            return
        }
        if panel.isVisible {
            panel.hide()
            shown = nil
        }
        schedule(view: view, range: range, after: Self.delay)
    }

    func present(view: RideTextView, range: NSRange) {
        timer?.cancel()
        word = range
        self.view = view
        lastFire = .distantPast
        fire(view: view, range: range)
    }

    func hide() {
        timer?.cancel()
        timer = nil
        word = nil
        shown = nil
        view = nil
        panel.hide()
    }

    static func bounds(for view: NSTextView) -> NSRect {
        guard let window = view.window else {
            return NSScreen.main?.visibleFrame ?? .zero
        }
        return window.convertToScreen(window.contentLayoutRect)
    }

    private func schedule(view: RideTextView, range: NSRange, after: Double) {
        timer?.cancel()
        word = range
        let work = DispatchWorkItem { [weak self, weak view] in
            guard let self, let view else {
                return
            }
            self.fire(view: view, range: range)
        }
        timer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: work)
    }

    private func fire(view: RideTextView, range: NSRange) {
        let since = Date().timeIntervalSince(lastFire)
        if since < Self.throttle {
            schedule(view: view, range: range, after: Self.throttle - since)
            return
        }
        lastFire = Date()
        view.hooks.definitions?(range.location) { [weak self, weak view] resp in
            guard let self, let view, self.word == range else {
                return
            }
            guard let content = HoverText.content(resp) else {
                return
            }
            var actual = NSRange()
            let anchor = view.firstRect(forCharacterRange: range, actualRange: &actual)
            self.shown = range
            self.view = view
            self.panel.show(content, anchor: anchor, bounds: Self.bounds(for: view))
        }
    }
}
