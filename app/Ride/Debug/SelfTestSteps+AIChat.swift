import AppKit

extension SelfTestSteps {
    static func aiChatSteps(e: SelfTestEditor) -> [SelfTestStep] {
        let ai = AIAssistant.shared
        let chat = AIChatStore.shared
        let lastError = { chat.current?.messages.last?.error ?? "" }
        return [
            SelfTestStep(name: "menu add selection to chat", wait: 0.5, until: { ai.showPanel && !chat.pending.isEmpty }, timeout: 5, run: {
                chat.pending = []
                e.activate()
                e.place(on: MenuBlock.call)
                SelfTestMenu.perform("Code › Add Selection to Chat")
            }, check: {
                let kinds = chat.pending.map(\.kind)
                return e.expect(ai.showPanel && kinds.first == .selection, "panel \(ai.showPanel) chips \(kinds)")
            }),
            explainStep("menu explain without key", path: "Code › Explain", prompt: AppState.explainSelectionPrompt, e: e),
            explainStep("menu explain file without key", path: "Code › Explain File", prompt: AppState.explainFilePrompt, e: e),
            SelfTestStep(name: "ai chat cleanup", run: {
                chat.pending = []
                ai.showPanel = false
            }, check: { e.expect(!ai.showPanel && chat.pending.isEmpty && lastError().contains("API key"), "panel \(ai.showPanel)") }),
        ]
    }

    private static func explainStep(_ name: String, path: String, prompt: String, e: SelfTestEditor) -> SelfTestStep {
        let chat = AIChatStore.shared
        let finished = { chat.current?.messages.last.map { !$0.streaming } ?? false }
        return SelfTestStep(name: name, wait: 0.5, until: { chat.current?.messages.first?.text == prompt && finished() }, timeout: 10, run: {
            e.activate()
            e.place(on: MenuBlock.call)
            SelfTestMenu.perform(path)
        }, check: {
            let messages = chat.current?.messages ?? []
            let attached = messages.first?.attachments.isEmpty == false
            let error = messages.last?.error ?? ""
            return e.expect(
                messages.count == 2 && attached && error.contains("API key saved"),
                "messages \(messages.count) attached \(attached) error '\(error)'"
            )
        })
    }
}
