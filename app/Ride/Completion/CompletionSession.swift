import AppKit

final class CompletionSession {
    static let shared = CompletionSession()
    let popup = CompletionPopupController()
    private var work: DispatchWorkItem?
    private var lifecycle: CompletionLifecycle?

    private init() {
        lifecycle = CompletionLifecycle(panel: popup.panel) { [weak self] in
            self?.hide()
        }
    }

    func hide() {
        work?.cancel()
        popup.hide()
    }

    var isVisible: Bool {
        popup.isVisible
    }

    func schedule(document: BufferDocument, view: RideTextView, state: AppState) {
        work?.cancel()
        if popup.suppress {
            popup.suppress = false
            hide()
            return
        }
        guard state.prefs.completions else {
            hide()
            return
        }
        let token = CompletionTokenizer.token(in: view.string, utf16: view.selectedRange().location)
        guard let token else {
            hide()
            return
        }
        let id = state.nextQueryId()
        let sessionId = document.sessionId ?? 0
        let work = DispatchWorkItem { [weak self] in
            self?.fire(token: token, queryId: id, sessionId: sessionId, view: view, state: state)
        }
        self.work = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.012, execute: work)
    }

    func viewportChanged(view: RideTextView) {
        guard popup.isVisible, popup.textView === view else {
            return
        }
        if CompletionPlacement.caretVisible(in: view) {
            popup.relocate(in: view)
        } else {
            hide()
        }
    }

    func selectionChanged(view: RideTextView) {
        guard popup.isVisible else {
            return
        }
        if CompletionTokenizer.token(in: view.string, utf16: view.selectedRange().location) == nil {
            hide()
        }
    }

    private static func context(_ position: CompletionPosition) -> CompletionContext {
        switch position {
        case .unknown: return .unknown
        case .typePosition: return .typePosition
        case .valuePosition: return .valuePosition
        case .memberAccess: return .memberAccess
        }
    }

    private func fire(token: CompletionToken, queryId: UInt64, sessionId: UInt64, view: RideTextView, state: AppState) {
        guard let engine = RideEngineClient.shared.engine else {
            return
        }
        let q = CompletionQuery(
            queryId: queryId,
            sessionId: sessionId,
            prefix: token.prefix,
            mode: token.mode,
            context: Self.context(token.position),
            cursorByte: token.cursorUtf8,
            replaceStartByte: token.replaceUtf8,
            currentCrate: token.currentCrate,
            currentModule: token.currentModule,
            kindFilter: nil,
            limit: 20
        )
        DispatchQueue.global(qos: .userInitiated).async {
            let resp = engine.queryCompletions(q: q)
            DispatchQueue.main.async {
                guard CompletionPopupController.accept(resp.queryId, latest: state.latestQueryId) else {
                    return
                }
                if resp.hits.isEmpty {
                    self.hide()
                    return
                }
                self.popup.show(
                    hits: resp.hits,
                    queryId: resp.queryId,
                    replaceUtf16: token.replaceUtf16,
                    in: view
                )
            }
        }
    }
}
