import AppKit

extension AppState {
    static let explainSelectionPrompt = "Explain what this code does: its purpose, how it works step by step, its inputs, outputs and side effects, and anything surprising or risky."
    static let explainFilePrompt = "Explain this file: its role in the project, its main items and how they fit together, and anything a newcomer should watch out for."

    func showChat(focus: Bool) {
        AIAssistant.shared.showPanel = true
        if focus {
            AIChatStore.shared.focusInput = true
        }
    }

    func sendChat() {
        let store = AIChatStore.shared
        store.send(store.input, config: prefs.aiChatConfig)
    }

    func addSelectionToChat() {
        guard let (view, document) = focusedEditor else {
            return
        }
        AIChatStore.shared.attach(AIChatContext.selection(view: view, document: document, root: workspaceRoot))
        showChat(focus: true)
    }

    func addFileToChat() {
        guard let (view, document) = focusedEditor else {
            return
        }
        AIChatStore.shared.attach([AIChatContext.file(document: document, text: view.string, root: workspaceRoot)])
        showChat(focus: true)
    }

    func explainSelection() {
        guard let (view, document) = focusedEditor else {
            return
        }
        let attachments = AIChatContext.selection(view: view, document: document, root: workspaceRoot)
        startExplain(Self.explainSelectionPrompt, attachments: attachments)
    }

    func explainFile() {
        guard let (view, document) = focusedEditor else {
            return
        }
        let attachments = [AIChatContext.file(document: document, text: view.string, root: workspaceRoot)]
        startExplain(Self.explainFilePrompt, attachments: attachments)
    }

    func suggestInline() {
        guard let (view, _) = focusedEditor else {
            return
        }
        AIInlineController.shared.trigger(view: view)
    }

    func insertAtCaret(_ code: String) {
        guard let (view, _) = focusedEditor, view.window != nil else {
            return
        }
        view.window?.makeFirstResponder(view)
        view.insertText(code, replacementRange: view.selectedRange())
    }

    func openChatLocation(path: String, line: Int) {
        let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : workspaceRoot?.appendingPathComponent(path)
        guard let url, FileManager.default.fileExists(atPath: url.path) else {
            showNotice("\(path) is not in this workspace")
            return
        }
        openFile(url, at: .line(line, mark: true))
    }

    private func startExplain(_ prompt: String, attachments: [AIChatAttachment]) {
        let store = AIChatStore.shared
        store.newThread()
        showChat(focus: false)
        store.send(prompt, config: prefs.aiChatConfig, attachments: attachments)
    }
}
