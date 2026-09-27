import AppKit

final class AICompletionSource {
    static let shared = AICompletionSource()
    static let delay = 0.4
    private var work: DispatchWorkItem?
    private var handle: AIRequestHandle?
    private var generation = 0
    private var reported: String?
    private var refetchWhenLanded = false

    func textChanged(document: BufferDocument, view: RideTextView, state: AppState, inserted: String) {
        guard state.prefs.aiComplete, !inserted.isEmpty else {
            cancel()
            return
        }
        if inFlightNarrows(inserted) {
            refetchWhenLanded = true
            return
        }
        schedule(document: document, view: view, state: state, delay: Self.delay)
    }

    private func inFlightNarrows(_ inserted: String) -> Bool {
        handle != nil && inserted.allSatisfy(CompletionTriggerGate.isIdentifierChar)
    }

    func trigger(view: RideTextView) {
        guard let binding = view.hooks.binding?(), binding.state.prefs.aiComplete else {
            return
        }
        schedule(document: binding.document, view: view, state: binding.state, delay: 0)
    }

    var isScheduled: Bool {
        work != nil
    }

    func cancel() {
        work?.cancel()
        work = nil
        handle?.cancel()
        handle = nil
        refetchWhenLanded = false
        generation += 1
    }

    private func schedule(document: BufferDocument, view: RideTextView, state: AppState, delay: Double) {
        cancel()
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
        guard view.window != nil, view.selectedRange().length == 0 else {
            return
        }
        let config = state.prefs.aiConfig
        let anchor = view.selectedRange().location
        let plan = AIContextBuilder.plan(document: document, view: view, state: state, level: config.level)
        generation += 1
        refetchWhenLanded = false
        let expected = generation
        handle = AIClient.complete({ plan.load() }, config: config) { [weak self, weak view, weak document, weak state] result in
            guard let self, expected == self.generation, let view, view.window != nil else {
                return
            }
            self.handle = nil
            switch result {
            case .success(let suggestions):
                AIClient.log.info("merging \(suggestions.count) suggestions at \(anchor)")
                let shown = CompletionSession.shared.merge(ai: suggestions, anchor: anchor, in: view)
                AIActivity.shared.report(AIOutcome.text(count: suggestions.count, shown: shown))
            case .failure(let error):
                AIActivity.shared.report("AI: failed")
                self.report(error, state: state)
            }
            if self.refetchWhenLanded, let document, let state {
                self.schedule(document: document, view: view, state: state, delay: Self.delay)
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
