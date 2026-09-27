import AppKit

final class PeekController {
    let panel = PeekPanel()
    private lazy var popup = CaretPopup(panel: panel)

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
        popup.anchor(at: view.selectedRange().location, in: view)
        let byte = UInt32(Utf16.utf8Offset(in: view.string, utf16: view.selectedRange().location))
        let expected = popup.begin()
        SessionService.shared.quickDefinition(document: binding.document, cursorByte: byte) { [weak self, weak view] excerpts in
            guard let self, let view, self.popup.accepts(expected), !excerpts.isEmpty else {
                return
            }
            self.present(excerpts, in: view)
        }
    }

    func caretMoved() {
        popup.caretMoved()
    }

    func hideIfUnpinned() {
        popup.hideIfUnpinned()
    }

    func hide() {
        popup.hide()
    }

    func togglePin() {
        popup.togglePin()
    }

    func openIfVisible() -> Bool {
        guard isVisible, let excerpt = panel.current(), let binding = popup.view?.hooks.binding?() else {
            return false
        }
        hide()
        let state = binding.state
        if excerpt.path.isEmpty || CaretPopup.samePath(excerpt.path, binding.document.fileURL?.path) {
            state.jumpTo(byte: excerpt.byteStart)
            return true
        }
        let url = URL(fileURLWithPath: excerpt.path)
        let inside = WorkspaceFS.contains(root: state.workspaceRoot, file: url)
        state.openFile(url, at: .byte(excerpt.byteStart), readOnly: !inside)
        return true
    }

    private func present(_ excerpts: [DefinitionExcerpt], in view: RideTextView) {
        popup.present(in: view)
        HoverController.shared.hide()
        CompletionSession.shared.hide()
        EditorPanes.shared.host(for: view)?.docsStorage?.hide()
        var actual = NSRange()
        let caret = view.selectedRange()
        let anchor = view.firstRect(forCharacterRange: NSRange(location: caret.location, length: 0), actualRange: &actual)
        panel.show(excerpts: excerpts, anchor: anchor, bounds: HoverController.bounds(for: view))
    }

}
