import AppKit

final class CheatSheetController {
    static let shared = CheatSheetController()
    let popup = CheatSheetPopup()
    private(set) var pinned = false
    private var response: CheatSheetResponse?
    private var work: DispatchWorkItem?
    private var generation: UInt64 = 0
    private var lifecycle: CompletionLifecycle?
    private weak var document: BufferDocument?
    private(set) weak var view: RideTextView?

    private init() {
        lifecycle = CompletionLifecycle(panel: popup.panel) { [weak self] in
            self?.close()
        }
        popup.onInsert = { [weak self] in
            _ = self?.insert()
        }
    }

    var isVisible: Bool {
        popup.isVisible
    }

    func follow(document: BufferDocument, view: RideTextView, state: AppState) {
        guard state.prefs.cheatSheet || pinned else {
            return
        }
        fetch(document: document, view: view)
    }

    func toggle(view: RideTextView) {
        if pinned {
            close()
            return
        }
        guard let binding = view.hooks.binding?(), binding.document.language.hasCompletions else {
            return
        }
        pinned = true
        fetch(document: binding.document, view: view)
    }

    func completionHidden() {
        if pinned, let view {
            relocate(in: view)
        } else {
            hidePopup()
        }
    }

    func textChanged(document: BufferDocument, view: RideTextView) {
        guard pinned else {
            return
        }
        fetch(document: document, view: view)
    }

    func caretMoved(view: RideTextView) {
        guard pinned, let document, self.view === view else {
            return
        }
        fetch(document: document, view: view)
    }

    func viewportChanged(view: RideTextView) {
        guard isVisible, self.view === view else {
            return
        }
        if CompletionPlacement.caretVisible(in: view) {
            relocate(in: view)
        } else {
            close()
        }
    }

    func relocate(in view: RideTextView) {
        guard isVisible else {
            return
        }
        let anchor = anchor(for: view)
        popup.relocate { CheatSheetPlacement.frame(size: $0, anchor: anchor) }
    }

    func close() {
        pinned = false
        hidePopup()
    }

    func move(_ delta: Int) {
        popup.move(delta)
    }

    func insert() -> Bool {
        guard isVisible, let entry = popup.selectedEntry, let response, let view else {
            return false
        }
        let session = CompletionSession.shared
        session.hide()
        close()
        let caret = view.selectedRange().location
        let start = min(Utf16.utf16Offset(in: view.string, utf8: Int(response.replaceStartByte)), caret)
        session.editSource = .completion
        let snippet = SnippetInsert.insert(entry.snippet, snippet: true, replacing: NSRange(location: start, length: caret - start), in: view)
        session.editSource = .user
        if let snippet {
            session.snippet = snippet
        }
        return true
    }

    private func anchor(for view: RideTextView) -> CheatSheetPlacement.Anchor {
        let popup = CompletionSession.shared.popup
        let visible = popup.isVisible && popup.textView === view
        return CheatSheetPlacement.Anchor(
            completion: visible ? popup.panel.frame : nil,
            completionAboveCaret: visible && popup.isAboveCaret(in: view),
            caret: CompletionPlacement.caretRect(in: view),
            screen: CompletionPlacement.screen(for: view)
        )
    }

    private func hidePopup() {
        work?.cancel()
        work = nil
        response = nil
        popup.hide()
    }

    private func fetch(document: BufferDocument, view: RideTextView) {
        work?.cancel()
        generation += 1
        let id = generation
        self.document = document
        self.view = view
        let work = DispatchWorkItem { [weak self, weak document, weak view] in
            guard let self, let document, let view else {
                return
            }
            CheatSheetFetch.run(document: document, view: view, all: false) { [weak self] resp in
                self?.received(resp, id: id, view: view)
            }
        }
        self.work = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.012, execute: work)
    }

    private func received(_ resp: CheatSheetResponse, id: UInt64, view: RideTextView) {
        guard id == generation, view.window != nil else {
            return
        }
        guard !resp.sections.isEmpty else {
            hidePopup()
            return
        }
        response = resp
        let anchor = anchor(for: view)
        popup.show(
            rows: CheatSheetRows.rows(resp.sections.map(CheatGroup.init)),
            prefix: resp.prefix,
            keeping: popup.selectedEntry?.name,
            shared: anchor.completion != nil
        ) { CheatSheetPlacement.frame(size: $0, anchor: anchor) }
    }
}
