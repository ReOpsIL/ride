import AppKit

enum CompletionEditSource {
    case user
    case completion
    case importLine
}

final class CompletionSession {
    static let shared = CompletionSession()
    let popup = CompletionPopupController()
    var snippet: SnippetSession?
    var list: CompletionList?
    var editSource = CompletionEditSource.user
    private var work: DispatchWorkItem?
    private var lifecycle: CompletionLifecycle?

    private init() {
        lifecycle = CompletionLifecycle(panel: popup.panel) { [weak self] in
            self?.hide()
        }
    }

    var isVisible: Bool {
        popup.isVisible
    }

    func hide() {
        work?.cancel()
        work = nil
        list = nil
        let view = popup.textView
        popup.hide()
        if let view {
            SignatureHelpController.shared.relocate(in: view)
        }
        CheatSheetController.shared.completionHidden()
    }

    func reset() {
        hide()
        AICompletionSource.shared.cancel()
        snippet = nil
        SignatureHelpController.shared.hide()
        CheatSheetController.shared.close()
    }

    func textChanged(document: BufferDocument, view: RideTextView, state: AppState, range: NSRange, inserted: String) {
        let length = inserted.utf16.count
        switch editSource {
        case .importLine:
            snippet?.shift(range: range, insertedLength: length)
            return
        case .completion:
            keepSnippet(range: range, length: length)
            return
        case .user:
            keepSnippet(range: range, length: length)
        }
        AICompletionSource.shared.textChanged(document: document, view: view, state: state, inserted: inserted)
        let engineOn = document.hasCompletions && state.prefs.completions
        let line = CompletionList.lineBeforeCaret(view)
        if inserted.isEmpty {
            deleted(document: document, view: view, state: state, line: line, engineOn: engineOn)
            return
        }
        if inserted.allSatisfy(CompletionTriggerGate.isIdentifierChar), narrow(in: view) {
            return
        }
        guard engineOn, CompletionTriggerGate.trigger(language: document.language, line: line, inserted: inserted) != nil else {
            hide()
            return
        }
        schedule(document: document, view: view, state: state)
    }

    func trigger(view: RideTextView) {
        AICompletionSource.shared.trigger(view: view)
        guard let binding = view.hooks.binding?(), binding.document.hasCompletions, binding.state.prefs.completions else {
            return
        }
        schedule(document: binding.document, view: view, state: binding.state)
    }

    /// Adds AI suggestions to the visible list, or shows a list of just them. Returns whether the popup is showing them.
    @discardableResult
    func merge(ai: [AISuggestion], anchor: Int, in view: RideTextView) -> Bool {
        let caret = view.selectedRange()
        guard caret.length == 0, caret.location >= anchor, view.window?.firstResponder === view,
              !CompletionList.typed(in: view, from: anchor).contains("\n")
        else {
            return false
        }
        let current = popup.isVisible && popup.textView === view ? list : nil
        let next = current?.merging(ai: ai, anchor: anchor) ?? CompletionList(ai: ai, anchor: anchor)
        return present(next, in: view, keepSelection: current != nil)
    }

    func schedule(document: BufferDocument, view: RideTextView, state: AppState) {
        work?.cancel()
        let request = CompletionFetch.Request(queryId: state.nextQueryId(), document: document, view: view, state: state)
        let work = DispatchWorkItem { [weak self] in
            CompletionFetch.run(request) { [weak self] resp, caret in
                self?.received(resp, caret: caret, request: request)
            }
        }
        self.work = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.012, execute: work)
    }

    func selectionChanged(view: RideTextView) {
        guard popup.isVisible, let list else {
            return
        }
        let selection = view.selectedRange()
        let typed = CompletionList.typed(in: view, from: list.replaceUtf16)
        if selection.length > 0 || selection.location < list.replaceUtf16 || typed.contains(where: \.isWhitespace) {
            hide()
        }
    }

    func viewportChanged(view: RideTextView) {
        guard popup.isVisible, popup.textView === view else {
            return
        }
        if CompletionPlacement.caretVisible(in: view) {
            popup.relocate(in: view)
            CheatSheetController.shared.relocate(in: view)
        } else {
            hide()
        }
    }

    private func deleted(document: BufferDocument, view: RideTextView, state: AppState, line: String, engineOn: Bool) {
        guard popup.isVisible else {
            return
        }
        if narrow(in: view) {
            return
        }
        guard engineOn, let last = line.last,
              CompletionTriggerGate.trigger(language: document.language, line: line, inserted: String(last)) != nil
        else {
            hide()
            return
        }
        schedule(document: document, view: view, state: state)
    }

    private func narrow(in view: RideTextView) -> Bool {
        guard popup.isVisible, let list, !list.truncated, view.selectedRange().location >= list.replaceUtf16 else {
            return false
        }
        return present(list, in: view, keepSelection: true)
    }

    @discardableResult
    private func present(_ list: CompletionList, in view: RideTextView, keepSelection: Bool) -> Bool {
        let prefix = CompletionList.typed(in: view, from: list.replaceUtf16)
        let hits = list.narrowed(prefix, in: view)
        guard !hits.isEmpty else {
            hide()
            return false
        }
        self.list = list
        let keep = keepSelection ? popup.selectedHit?.name : nil
        popup.show(hits: hits, prefix: prefix, truncated: list.truncated, selectedName: keep, in: view)
        SignatureHelpController.shared.relocate(in: view)
        if let binding = view.hooks.binding?() {
            CheatSheetController.shared.follow(document: binding.document, view: view, state: binding.state)
        }
        return true
    }

    private func received(_ resp: CompletionResponse, caret: Int, request: CompletionFetch.Request) {
        guard let view = request.view, let state = request.state, view.window != nil,
              CompletionGate.accept(resp.queryId, latest: state.latestQueryId)
        else {
            return
        }
        guard !resp.hits.isEmpty else {
            hide()
            return
        }
        let kept = popup.isVisible && popup.textView === view ? list : nil
        present(CompletionList(response: resp, text: view.string, ai: kept?.ai ?? [], aiAnchor: kept?.aiAnchor), in: view, keepSelection: false)
        if resp.truncated, view.selectedRange().location != caret, let document = request.document {
            schedule(document: document, view: view, state: state)
        }
    }
}
