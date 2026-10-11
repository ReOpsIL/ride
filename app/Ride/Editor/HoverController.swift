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
    private var card: HoverContent?
    private var rendered: QuickDoc?
    private var anchor: NSRect = .zero
    private var exitHide: DispatchWorkItem?

    private init() {
        lifecycle = CompletionLifecycle(panel: panel.panel) { [weak self] in
            self?.hide()
        }
        panel.onClick = { [weak self] in
            _ = self?.upgradeIfVisible()
        }
        panel.onMouseExit = { [weak self] in
            self?.notePointerLeft()
        }
    }

    var isVisible: Bool {
        panel.isVisible
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
        let range = IdentifierRange.at(view.string as NSString, index: index)
        if panel.isVisible {
            if staying(on: range) {
                exitHide?.cancel()
                exitHide = nil
                if word != shown {
                    timer?.cancel()
                    timer = nil
                    word = shown
                }
                return
            }
            armExit()
            if let range, range != word {
                schedule(view: view, range: range, after: Self.delay)
            }
            return
        }
        guard let range else {
            hide()
            return
        }
        if range == word {
            return
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
        exitHide?.cancel()
        exitHide = nil
        word = nil
        shown = nil
        view = nil
        card = nil
        rendered = nil
        anchor = .zero
        panel.hide()
    }

    func notePointerLeft() {
        guard panel.isVisible else {
            return
        }
        if staying(on: nil) {
            exitHide?.cancel()
            exitHide = nil
            return
        }
        armExit()
    }

    private func staying(on range: NSRange?) -> Bool {
        if let shown, range == shown { return true }
        if panel.containsMouse() { return true }
        return HoverReach.contains(mouse: NSEvent.mouseLocation, anchor: anchor, card: panel.screenFrame)
    }

    private func armExit() {
        guard exitHide == nil else { return }
        let work = DispatchWorkItem { [weak self] in self?.abandon() }
        exitHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func abandon() {
        exitHide = nil
        guard !staying(on: nil) else {
            return
        }
        if word != shown, timer != nil {
            panel.hide()
            shown = nil
            card = nil
            rendered = nil
            anchor = .zero
            return
        }
        hide()
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
        let started = DebugHover.request(view: view, range: range) { [weak self, weak view] content in
            guard let self, let view, self.word == range else {
                return
            }
            guard let content else {
                self.showDefinition(view: view, range: range)
                return
            }
            self.show(content, view: view, range: range)
        }
        if !started {
            showDefinition(view: view, range: range)
        }
    }

    private func showDefinition(view: RideTextView, range: NSRange) {
        card = nil
        rendered = nil
        view.hooks.definitions?(range.location) { [weak self, weak view] resp in
            guard let self, let view, self.word == range else {
                return
            }
            self.card = HoverText.content(resp)
            self.publish(view: view, range: range)
        }
        guard let binding = view.hooks.binding?() else {
            return
        }
        let byte = UInt32(Utf16.utf8Offset(in: view.string, utf16: range.location))
        SessionService.shared.quickDoc(document: binding.document, cursorByte: byte) { [weak self, weak view] doc in
            guard let self, let view, self.word == range else {
                return
            }
            self.rendered = doc
            self.publish(view: view, range: range)
        }
    }

    private func publish(view: RideTextView, range: NSRange) {
        guard let content = HoverText.documented(card, rendered: rendered) else {
            return
        }
        show(content, view: view, range: range)
    }

    private func show(_ content: HoverContent, view: RideTextView, range: NSRange) {
        var actual = NSRange()
        let anchor = view.firstRect(forCharacterRange: range, actualRange: &actual)
        shown = range
        self.view = view
        self.anchor = anchor
        panel.show(content, anchor: anchor, bounds: Self.bounds(for: view))
    }
}
