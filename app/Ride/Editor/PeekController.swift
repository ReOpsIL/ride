import AppKit

final class PeekController {
    let panel = PeekPanel()
    private(set) var pinned = false
    private var generation: UInt64 = 0
    private weak var view: RideTextView?
    private var openedAt: NSRange?

    init() {
        panel.onPin = { [weak self] in
            self?.togglePin()
        }
        panel.onOpen = { [weak self] in
            _ = self?.openIfVisible()
        }
    }

    var isVisible: Bool {
        panel.isVisible
    }

    var excerptText: String {
        panel.excerptText
    }

    var segmentCount: Int {
        panel.excerpts.count
    }

    var labels: [String] {
        panel.excerpts.map(\.label)
    }

    static func showFocused() {
        guard let host = EditorPanes.shared.focused else {
            return
        }
        host.peek.showAtCaret(in: host.textView)
    }

    func showAtCaret(in view: RideTextView) {
        guard let binding = view.hooks.binding?() else {
            return
        }
        openedAt = IdentifierRange.at(view.string as NSString, index: view.selectedRange().location)
        let byte = UInt32(Utf16.utf8Offset(in: view.string, utf16: view.selectedRange().location))
        generation += 1
        let expected = generation
        SessionService.shared.quickDefinition(document: binding.document, cursorByte: byte) { [weak self, weak view] excerpts in
            guard let self, let view, expected == self.generation, !excerpts.isEmpty else {
                return
            }
            self.present(excerpts, in: view)
        }
    }

    func pin() {
        pinned = true
        panel.setPinned(true)
    }

    func caretMoved() {
        guard isVisible, !pinned, let view else {
            return
        }
        let caret = view.selectedRange()
        if let openedAt, caret.length == 0, NSLocationInRange(caret.location, openedAt) {
            return
        }
        if let openedAt, let current = IdentifierRange.at(view.string as NSString, index: caret.location), current == openedAt {
            return
        }
        hide()
    }

    func hideIfUnpinned() {
        if !pinned {
            hide()
        }
    }

    func hide() {
        generation += 1
        pinned = false
        view = nil
        openedAt = nil
        panel.hide()
    }

    func togglePin() {
        pinned.toggle()
        panel.setPinned(pinned)
    }

    func openIfVisible() -> Bool {
        guard isVisible, let excerpt = panel.current(), let binding = view?.hooks.binding?() else {
            return false
        }
        hide()
        let state = binding.state
        if excerpt.path.isEmpty || Self.same(excerpt.path, binding.document.fileURL?.path) {
            state.jumpTo(byte: excerpt.byteStart)
            return true
        }
        let url = URL(fileURLWithPath: excerpt.path)
        let inside = WorkspaceFS.contains(root: state.workspaceRoot, file: url)
        state.pendingJump = excerpt.byteStart
        state.openFile(url, readOnly: !inside)
        return true
    }

    private func present(_ excerpts: [DefinitionExcerpt], in view: RideTextView) {
        self.view = view
        HoverController.shared.hide()
        CompletionSession.shared.hide()
        EditorPanes.shared.host(for: view)?.docsStorage?.hide()
        var actual = NSRange()
        let caret = view.selectedRange()
        let anchor = view.firstRect(forCharacterRange: NSRange(location: caret.location, length: 0), actualRange: &actual)
        panel.show(excerpts: excerpts, anchor: anchor, bounds: HoverController.bounds(for: view))
    }

    private static func same(_ path: String, _ other: String?) -> Bool {
        guard let other else {
            return false
        }
        return URL(fileURLWithPath: path).standardizedFileURL == URL(fileURLWithPath: other).standardizedFileURL
    }
}
