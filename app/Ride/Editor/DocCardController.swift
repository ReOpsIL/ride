import AppKit

enum DocCardState: Equatable {
    case idle
    case pending(NSRange)
    case shown(NSRange)

    var word: NSRange? {
        switch self {
        case .idle:
            return nil
        case let .pending(range), let .shown(range):
            return range
        }
    }
}

final class DocCardController {
    static let shared = DocCardController()
    private let panel = DocCardPanel()
    private var lifecycle: CompletionLifecycle?
    private(set) var state = DocCardState.idle
    private weak var view: RideTextView?
    private var shownAt = NSPoint.zero

    private init() {
        lifecycle = CompletionLifecycle(panel: panel.panel) { [weak self] in
            self?.hide()
        }
        panel.onClick = { [weak self] in
            _ = self?.upgrade()
        }
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func upgrade() -> Bool {
        guard let view, let word = state.word else {
            return false
        }
        hide()
        EditorPanes.shared.host(for: view)?.docs.show(utf16: word.location, in: view)
        return true
    }

    func upgradeAtCaret(in view: RideTextView) -> Bool {
        guard view === self.view, let word = state.word, word == Self.word(atCaretOf: view) else {
            return false
        }
        return upgrade()
    }

    @discardableResult
    func showAtCaret(in view: RideTextView) -> Bool {
        guard let range = Self.word(atCaretOf: view) else {
            return false
        }
        present(view: view, range: range)
        return true
    }

    func present(view: RideTextView, range: NSRange) {
        panel.hide()
        state = .pending(range)
        self.view = view
        let started = DebugHover.request(view: view, range: range) { [weak self, weak view] content in
            guard let self, let view, self.state == .pending(range) else {
                return
            }
            guard let content else {
                self.fetchDoc(view: view, range: range)
                return
            }
            self.show(content, view: view, range: range)
        }
        if !started {
            fetchDoc(view: view, range: range)
        }
    }

    func viewportChanged(in view: RideTextView) {
        guard case .shown = state, view === self.view, view.visibleRect.origin != shownAt else {
            return
        }
        hide()
    }

    func hide() {
        state = .idle
        view = nil
        panel.hide()
    }

    static func bounds(for view: NSTextView) -> NSRect {
        guard let window = view.window else {
            return NSScreen.main?.visibleFrame ?? .zero
        }
        return window.convertToScreen(window.contentLayoutRect)
    }

    private static func word(atCaretOf view: RideTextView) -> NSRange? {
        IdentifierRange.at(view.string as NSString, index: view.selectedRange().location)
    }

    private func fetchDoc(view: RideTextView, range: NSRange) {
        guard let binding = view.hooks.binding?() else {
            hide()
            return
        }
        let byte = UInt32(Utf16.utf8Offset(in: view.string, utf16: range.location))
        SessionService.shared.quickDoc(document: binding.document, cursorByte: byte) { [weak self, weak view] doc in
            guard let self, let view, self.state == .pending(range) else {
                return
            }
            guard let doc, let content = HoverText.shown(doc) else {
                self.hide()
                return
            }
            self.show(content, view: view, range: range)
        }
    }

    private func show(_ content: HoverContent, view: RideTextView, range: NSRange) {
        var actual = NSRange()
        let anchor = view.firstRect(forCharacterRange: range, actualRange: &actual)
        state = .shown(range)
        self.view = view
        shownAt = view.visibleRect.origin
        panel.show(content, anchor: anchor, bounds: Self.bounds(for: view))
    }
}
