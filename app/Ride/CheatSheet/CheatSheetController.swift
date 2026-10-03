import AppKit

final class CheatSheetController {
    static let shared = CheatSheetController()
    let popup = CheatSheetPopup()
    private(set) var pinned = false
    var search = PopupSearch()
    private var browsing = false
    private(set) var response: CheatSheetResponse?
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
        popup.onBrowse = { [weak self] in
            self?.focus()
        }
        popup.onSearch = { [weak self] in
            self.map(PopupSearchRouter.begin)
        }
    }

    var focused: Bool {
        browsing || search.isActive
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
        focus()
        popup.move(delta)
    }

    func focus() {
        guard !browsing else {
            return
        }
        browsing = true
        popup.setHints(hints(shared: CompletionSession.shared.isVisible))
    }

    func blur() {
        guard browsing else {
            return
        }
        browsing = false
        popup.setHints(hints(shared: CompletionSession.shared.isVisible))
    }

    private func hints(shared: Bool) -> CheatSheetLayout.Hints {
        if search.isActive {
            return .searching
        }
        if !shared {
            return .alone
        }
        return focused ? .focused : .shared
    }

    private func hidePopup() {
        work?.cancel()
        work = nil
        response = nil
        browsing = false
        search = PopupSearch()
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
            CheatSheetFetch.run(document: document, view: view) { [weak self] resp in
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
        browsing = false
        present(in: view)
    }

    func present(in view: RideTextView) {
        guard let response else {
            return
        }
        let anchor = anchor(for: view)
        popup.show(
            rows: CheatSheetRows.rows(response.sections.map(CheatGroup.init), search: search),
            prefix: response.prefix,
            search: search,
            keeping: popup.selectedEntry?.name,
            hints: hints(shared: anchor.completion != nil)
        ) { CheatSheetPlacement.frame(size: $0, anchor: anchor) }
    }
}
