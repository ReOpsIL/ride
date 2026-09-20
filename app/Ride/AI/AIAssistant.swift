import AppKit

final class AIAssistant: ObservableObject {
    static let shared = AIAssistant()
    @Published var showPrompt = false
    @Published var prompt = ""
    @Published var level = AIContextLevel.function.rawValue
    @Published var selection = ""
    @Published var showPanel = false {
        didSet { onPanelChange?() }
    }
    var onPanelChange: (() -> Void)?
    @Published private(set) var question = ""
    @Published private(set) var answer = ""
    @Published private(set) var error: String?
    private weak var document: BufferDocument?
    private weak var view: RideTextView?
    private weak var state: AppState?
    private var handle: AIRequestHandle?

    func askFromEditor(state: AppState) {
        guard let (view, document) = state.focusedEditor else {
            return
        }
        self.document = document
        self.view = view
        self.state = state
        let range = view.selectedRange()
        selection = range.length > 0 ? (view.string as NSString).substring(with: range) : ""
        let tokens = CommentTokens.tokens(for: document.language)
        prompt = AICommentPrompt.extract(view.string, caret: range.location, tokens: tokens) ?? prompt
        level = state.prefs.aiContext
        showPrompt = true
    }

    func send() {
        showPrompt = false
        let request = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty, let document, let view, let state else {
            return
        }
        let config = AIConfig(provider: state.prefs.aiProvider, model: state.prefs.aiModel, auth: state.prefs.aiAuth, level: level)
        let plan = AIContextBuilder.plan(document: document, view: view, state: state, level: config.level)
        let selected = selection.isEmpty ? nil : selection
        question = request
        answer = ""
        error = nil
        showPanel = true
        handle?.cancel()
        handle = AIClient.ask({ (plan.load(), request, selected) }, config: config) { [weak self] result in
            switch result {
            case .success(let text):
                self?.answer = text
            case .failure(let failure):
                self?.error = failure.message
            }
        }
    }

    func insertAnswer() {
        guard let view, view.window != nil, !answer.isEmpty else {
            return
        }
        view.window?.makeFirstResponder(view)
        view.insertText(AIAnswerText.code(in: answer), replacementRange: view.selectedRange())
    }

    func copyAnswer() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(answer, forType: .string)
    }
}
