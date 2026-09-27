import AppKit

final class DocController {
    static let noExternalNotice = "No external documentation for this symbol"
    let panel = DocPanel()
    private lazy var popup = CaretPopup(panel: panel)

    init() {
        panel.onPin = { [weak self] in
            self?.togglePin()
        }
        panel.onLink = { [weak self] target in
            self?.open(target: target)
        }
    }

    var isVisible: Bool {
        panel.isVisible
    }

    var html: String {
        panel.html
    }

    static func showFocused() {
        if HoverController.shared.upgradeIfVisible() {
            return
        }
        guard let host = EditorPanes.shared.focused else {
            return
        }
        host.docs.showAtCaret(in: host.textView)
    }

    static func showExternalFocused() {
        guard let host = EditorPanes.shared.focused else {
            return
        }
        host.docs.showExternal(in: host.textView)
    }

    static func showCompletion(in view: RideTextView, name: String? = nil) {
        let popup = CompletionSession.shared.popup
        let item = name.flatMap { popup.hitNamed($0) }
            ?? name.flatMap { n in CompletionSession.shared.list?.base.first { $0.name == n } }
            ?? popup.selectedHit
        guard let hit = item?.hit else {
            return
        }
        EditorPanes.shared.host(for: view)?.docs.show(hit: hit, in: view)
    }

    func showAtCaret(in view: RideTextView) {
        show(utf16: view.selectedRange().location, in: view)
    }

    func show(utf16: Int, in view: RideTextView) {
        guard let binding = view.hooks.binding?() else {
            return
        }
        popup.anchor(at: utf16, in: view)
        let byte = UInt32(Utf16.utf8Offset(in: view.string, utf16: utf16))
        fetch(document: binding.document, view: view, byte: byte)
    }

    func show(hit: CompletionHit, in view: RideTextView) {
        guard let binding = view.hooks.binding?() else {
            return
        }
        popup.anchor(at: view.selectedRange().location, in: view)
        let byte = hit.nameByte ?? hit.byteStart
        if let path = hit.sourcePath, let byte, !CaretPopup.samePath(path, binding.document.fileURL?.path) {
            fetch(path: path, byte: byte, view: view)
            return
        }
        let caret = UInt32(Utf16.utf8Offset(in: view.string, utf16: view.selectedRange().location))
        fetch(document: binding.document, view: view, byte: byte ?? caret)
    }

    func showExternal(in view: RideTextView) {
        guard let binding = view.hooks.binding?() else {
            return
        }
        let state = binding.state
        Definitions.lookup(document: binding.document, view: view, utf16: view.selectedRange().location) { resp in
            guard let hit = resp.hits.first,
                  let url = DocExternal.url(name: hit.name, crate: hit.crateName, path: hit.path)
            else {
                state.showNotice(Self.noExternalNotice)
                return
            }
            NSWorkspace.shared.open(url)
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

    func open(target: String) {
        guard let view = popup.view, let binding = view.hooks.binding?() else {
            return
        }
        let leaf = target.split(separator: ":").filter { !$0.isEmpty }.last.map(String.init) ?? target
        if let item = binding.document.outline.first(where: { $0.name == leaf }) {
            fetch(document: binding.document, view: view, byte: item.startByte)
            return
        }
        let range = (view.string as NSString).range(of: leaf)
        if range.location != NSNotFound {
            show(utf16: range.location, in: view)
        }
    }

    private func fetch(document: BufferDocument, view: RideTextView, byte: UInt32) {
        let expected = popup.begin()
        SessionService.shared.quickDoc(document: document, cursorByte: byte) { [weak self, weak view] doc in
            guard let self, let view, self.popup.accepts(expected), let doc else {
                return
            }
            self.present(doc, in: view)
        }
    }

    private func fetch(path: String, byte: UInt32, view: RideTextView) {
        let expected = popup.begin()
        SessionService.shared.quickDoc(path: path, byte: byte) { [weak self, weak view] doc in
            guard let self, let view, self.popup.accepts(expected), let doc else {
                return
            }
            self.present(doc, in: view)
        }
    }

    private func present(_ doc: QuickDoc, in view: RideTextView) {
        popup.present(in: view)
        HoverController.shared.hide()
        CompletionSession.shared.hide()
        EditorPanes.shared.host(for: view)?.peekStorage?.hide()
        var actual = NSRange()
        let caret = view.selectedRange()
        let anchor = view.firstRect(forCharacterRange: NSRange(location: caret.location, length: 0), actualRange: &actual)
        panel.show(
            title: doc.title,
            origin: DocPage.origin(path: doc.originPath, line: doc.originLine),
            html: DocPage.html(title: doc.title, signature: doc.signature, body: doc.html),
            anchor: anchor,
            bounds: HoverController.bounds(for: view)
        )
    }

}
