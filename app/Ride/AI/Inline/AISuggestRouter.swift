import AppKit

enum AISuggestRouter {
    static func textChanged(document: BufferDocument, view: RideTextView, state: AppState, inserted: String) {
        if state.prefs.assistant.inlineSuggestions {
            AIInlineController.shared.textChanged(document: document, view: view, state: state, inserted: inserted)
        } else {
            AICompletionSource.shared.textChanged(document: document, view: view, state: state, inserted: inserted)
        }
    }

    static func trigger(view: RideTextView) {
        guard let binding = view.hooks.binding?(), binding.state.prefs.aiComplete else {
            return
        }
        if binding.state.prefs.assistant.inlineSuggestions {
            AIInlineController.shared.trigger(view: view)
        } else {
            AICompletionSource.shared.trigger(view: view)
        }
    }

    static func cancel() {
        AICompletionSource.shared.cancel()
        AIInlineController.shared.cancel()
    }
}
