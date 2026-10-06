import AppKit

final class AIInlineController {
    static let shared = AIInlineController()
    static let delay = 0.3
    private var work: DispatchWorkItem?
    private var handle: AIRequestHandle?
    private var generation = 0
    private var reported: String?

    var isScheduled: Bool {
        work != nil
    }

    func textChanged(document: BufferDocument, view: RideTextView, state: AppState, inserted: String) {
        if let ghost = view.inlineGhost {
            if let next = ghost.advanced(by: inserted), view.selectedRange() == NSRange(location: next.location, length: 0) {
                present(next, in: view)
                return
            }
            hide(in: view)
        }
        cancelRequest()
        guard state.prefs.aiComplete, !inserted.isEmpty else {
            return
        }
        schedule(document: document, view: view, state: state, delay: Self.delay)
    }

    func caretMoved(in view: RideTextView) {
        guard let ghost = view.inlineGhost else {
            return
        }
        let caret = view.selectedRange()
        guard caret.length > 0 || !AIInlineLine.typedThrough(view.string, ghost: ghost, caret: caret.location) else {
            return
        }
        hide(in: view)
        cancelRequest()
    }

    func trigger(view: RideTextView) {
        guard let binding = view.hooks.binding?() else {
            return
        }
        schedule(document: binding.document, view: view, state: binding.state, delay: 0)
    }

    func accept(in view: RideTextView) -> Bool {
        guard let ghost = view.inlineGhost else {
            return false
        }
        insert(ghost.remaining, in: view)
        hide(in: view)
        return true
    }

    func acceptWord(in view: RideTextView) -> Bool {
        guard let ghost = view.inlineGhost else {
            return false
        }
        let chunk = ghost.nextChunk
        guard !chunk.isEmpty else {
            return accept(in: view)
        }
        insert(chunk, in: view)
        if let next = ghost.advanced(by: chunk) {
            present(next, in: view)
        } else {
            hide(in: view)
        }
        return true
    }

    func dismiss(in view: RideTextView) -> Bool {
        guard view.inlineGhost != nil else {
            return false
        }
        hide(in: view)
        cancelRequest()
        return true
    }

    func cancel() {
        cancelRequest()
    }

    private func insert(_ text: String, in view: RideTextView) {
        let session = CompletionSession.shared
        session.editSource = .completion
        view.insertText(text, replacementRange: view.selectedRange())
        session.editSource = .user
    }

    func present(_ ghost: AIInlineGhost, in view: RideTextView) {
        let old = view.inlineGhost
        view.inlineGhost = ghost
        view.refreshFragments(in: [old?.location, ghost.location].compactMap { $0 }.map { NSRange(location: $0, length: 0) })
    }

    private func hide(in view: RideTextView) {
        guard let old = view.inlineGhost else {
            return
        }
        view.inlineGhost = nil
        view.refreshFragments(in: [NSRange(location: old.location, length: 0)])
    }

    private func cancelRequest() {
        work?.cancel()
        work = nil
        handle?.cancel()
        handle = nil
        generation += 1
    }

    private func schedule(document: BufferDocument, view: RideTextView, state: AppState, delay: Double) {
        cancelRequest()
        let item = DispatchWorkItem { [weak self, weak document, weak view, weak state] in
            guard let self, let document, let view, let state else {
                return
            }
            self.work = nil
            self.fire(document: document, view: view, state: state)
        }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func fire(document: BufferDocument, view: RideTextView, state: AppState) {
        let caret = view.selectedRange()
        guard view.window != nil, caret.length == 0, AIInlineLine.restIsBlank(view.string, caret: caret.location) else {
            return
        }
        let config = state.prefs.aiConfig
        let plan = AIContextBuilder.plan(document: document, view: view, state: state, level: config.level)
        let expected = generation
        let textGeneration = view.textGeneration
        handle = AIClient.complete({ plan.load() }, config: config, system: AIPrompt.inlineSystem) { [weak self, weak view, weak state] result in
            guard let self, let view, expected == self.generation, view.textGeneration == textGeneration,
                  view.selectedRange() == caret, view.window != nil
            else {
                return
            }
            self.handle = nil
            switch result {
            case .success(let suggestions):
                let line = AIInlineLine.beforeCaret(view.string, caret: caret.location)
                if let text = suggestions.first.flatMap({ AIInlineGhost.cleaned($0.text, lineBeforeCaret: line) }) {
                    self.present(AIInlineGhost(anchor: caret.location, text: text), in: view)
                    AIActivity.shared.report("AI: suggestion (Tab accepts)")
                } else {
                    AIActivity.shared.report("AI: no suggestion")
                }
            case .failure(let error):
                AIActivity.shared.report("AI: failed")
                self.report(error, state: state)
            }
        }
    }

    private func report(_ error: AIError, state: AppState?) {
        let message = "AI completion: \(error.message)"
        guard reported != message else {
            return
        }
        reported = message
        state?.showNotice(message)
    }
}
