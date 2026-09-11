import AppKit

final class DocController {
    let panel = DocPanel()
    private(set) var pinned = false
    private var generation: UInt64 = 0
    private weak var view: RideTextView?
    private var openedAt: NSRange?

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
        let hit = name.flatMap { popup.hitNamed($0) }
            ?? name.flatMap { n in CompletionSession.shared.list?.base.first { $0.name == n } }
            ?? popup.selectedHit
        guard let hit else {
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
        openedAt = IdentifierRange.at(view.string as NSString, index: utf16)
        let byte = UInt32(Utf16.utf8Offset(in: view.string, utf16: utf16))
        fetch(document: binding.document, view: view, byte: byte)
    }

    func show(hit: CompletionHit, in view: RideTextView) {
        guard let binding = view.hooks.binding?() else {
            return
        }
        openedAt = IdentifierRange.at(view.string as NSString, index: view.selectedRange().location)
        if let path = hit.sourcePath, let byte = hit.byteStart, !Self.same(path, binding.document.fileURL?.path) {
            fetch(path: path, byte: byte, name: hit.name, view: view)
            return
        }
        let caret = UInt32(Utf16.utf8Offset(in: view.string, utf16: view.selectedRange().location))
        fetch(document: binding.document, view: view, byte: hit.byteStart ?? caret)
    }

    func showExternal(in view: RideTextView) {
        guard let binding = view.hooks.binding?() else {
            return
        }
        Definitions.lookup(document: binding.document, view: view, utf16: view.selectedRange().location) { resp in
            guard let hit = resp.hits.first,
                  let url = DocExternal.url(name: hit.name, crate: hit.crateName, path: hit.path)
            else {
                return
            }
            NSWorkspace.shared.open(url)
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

    func open(target: String) {
        guard let view, let binding = view.hooks.binding?() else {
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
        generation += 1
        let expected = generation
        SessionService.shared.quickDoc(document: document, cursorByte: byte) { [weak self, weak view] doc in
            guard let self, let view, expected == self.generation, let doc else {
                return
            }
            self.present(doc, in: view)
        }
    }

    private func fetch(path: String, byte: UInt32, name: String, view: RideTextView) {
        generation += 1
        let expected = generation
        SessionService.shared.quickDoc(path: path, byte: byte, name: name) { [weak self, weak view] doc in
            guard let self, let view, expected == self.generation, let doc else {
                return
            }
            self.present(doc, in: view)
        }
    }

    private func present(_ doc: QuickDoc, in view: RideTextView) {
        self.view = view
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

    private static func same(_ path: String, _ other: String?) -> Bool {
        guard let other else {
            return false
        }
        return URL(fileURLWithPath: path).standardizedFileURL == URL(fileURLWithPath: other).standardizedFileURL
    }
}
