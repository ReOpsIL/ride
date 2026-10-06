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
    private weak var document: BufferDocument?
    private weak var view: RideTextView?
    private weak var state: AppState?

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
        prompt = AICommentPrompt.extract(view.string, caret: range.location, tokens: tokens) ?? ""
        level = state.prefs.aiContext
        showPrompt = true
    }

    func send() {
        showPrompt = false
        let request = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty, let document, let view, let state else {
            return
        }
        let level = AIContextLevel(rawValue: level) ?? .function
        let attachments = AIChatContext.selection(view: view, document: document, root: state.workspaceRoot)
            + wider(level, document: document, view: view, state: state)
        let store = AIChatStore.shared
        store.newThread()
        showPanel = true
        store.send(request, config: state.prefs.aiChatConfig, attachments: attachments)
    }

    private func wider(_ level: AIContextLevel, document: BufferDocument, view: RideTextView, state: AppState) -> [AIChatAttachment] {
        switch level {
        case .block, .function:
            return []
        case .file:
            return [AIChatContext.file(document: document, text: view.string, root: state.workspaceRoot)]
        case .directory, .project:
            let file = AIChatContext.file(document: document, text: view.string, root: state.workspaceRoot)
            let extras = AIContextBuilder.plan(document: document, view: view, state: state, level: level).load().extras
            return [file] + extras.map {
                AIChatAttachment(kind: .file, path: $0.path, line: 1, text: $0.text, truncated: false)
            }
        }
    }
}
