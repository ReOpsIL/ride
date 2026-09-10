import AppKit

final class SignatureHelpController {
    static let shared = SignatureHelpController()
    private let panel: NSPanel
    private let content = SignatureHelpView(frame: NSRect(x: 0, y: 0, width: 200, height: 40))
    private var lifecycle: CompletionLifecycle?
    private var generation: UInt64 = 0
    private weak var view: RideTextView?

    private init() {
        panel = OverlayPanel.make(size: content.frame.size)
        panel.contentView = content
        lifecycle = CompletionLifecycle(panel: panel) { [weak self] in
            self?.hide()
        }
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func textChanged(document: BufferDocument, view: RideTextView, inserted: String) {
        guard document.language.hasSignatureHelp else {
            return
        }
        if inserted == "(" || inserted == "," {
            show(document: document, view: view)
        } else if inserted == ")" || inserted.contains("\n") {
            hide()
        }
    }

    func caretMoved(document: BufferDocument, view: RideTextView) {
        guard isVisible else {
            return
        }
        show(document: document, view: view)
    }

    func show(document: BufferDocument, view: RideTextView) {
        guard document.language.hasSignatureHelp else {
            return
        }
        generation += 1
        let expected = generation
        let cursor = UInt32(Utf16.utf8Offset(in: view.string, utf16: view.selectedRange().location))
        SessionService.shared.signatureHelp(document: document, cursorByte: cursor) { [weak self, weak view] help in
            guard let self, let view, expected == self.generation else {
                return
            }
            guard let help else {
                self.hide()
                return
            }
            self.present(help, in: view)
        }
    }

    func hide() {
        generation += 1
        view = nil
        panel.orderOut(nil)
    }

    func relocate(in view: RideTextView) {
        guard isVisible, self.view === view else {
            return
        }
        if CompletionPlacement.caretVisible(in: view) {
            panel.setFrame(frame(size: panel.frame.size, in: view), display: true)
        } else {
            hide()
        }
    }

    private func present(_ help: SignatureHelp, in view: RideTextView) {
        self.view = view
        let size = content.fill(help)
        OverlayPanel.present(panel, frame: frame(size: size, in: view))
    }

    private func frame(size: NSSize, in view: RideTextView) -> NSRect {
        let popup = CompletionSession.shared.popup
        let below = popup.isVisible && popup.isAboveCaret(in: view)
        let screen = view.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        return SignatureHelpPlacement.frame(
            size: size,
            caret: CompletionPlacement.caretRect(in: view),
            screen: screen,
            below: below
        )
    }
}
