import AppKit

extension DemoScene {
    static func assistant(_ name: String, state: AppState) -> Bool {
        switch name {
        case "chat":
            state.prefs.outlinePanel = false
            editor(state, file: "src/main.rs", line: 8)
            DemoLaunch.after(1.5) { stageChat(state, pending: true) }
            ready(after: 3.5)
        case "chatempty":
            state.prefs.outlinePanel = false
            editor(state)
            DemoLaunch.after(1.0) {
                AIChatStore.shared.restore([], current: nil)
                state.showChat(focus: true)
            }
            ready(after: 2.5)
        case "ghost":
            state.prefs.outlinePanel = false
            editor(state, file: "src/main.rs", line: 12)
            DemoLaunch.after(1.5) { stageGhost(state, anchor: DemoChatScript.ghostAnchor, typed: "\n    let", text: DemoChatScript.ghostText) }
            ready(after: 3.0)
        case "ghostvision":
            state.prefs.codeVision = true
            state.prefs.outlinePanel = false
            editor(state)
            DemoLaunch.after(1.2) { _ = open(state, file: "src/util.rs") }
            ready(when: { ghostVisionStaged(state) })
        default:
            return false
        }
        return true
    }

    private static func stageChat(_ state: AppState, pending: Bool) {
        let e = SelfTestEditor(state: state)
        e.activate()
        e.place(on: "counter.record(\"ride\");")
        guard let view = e.view, let document = state.activeBuffer else {
            return
        }
        let line = (view.string as NSString).lineRange(for: view.selectedRange())
        view.setSelectedRange(NSRange(location: line.location, length: line.length * 2))
        let attachments = AIChatContext.selection(view: view, document: document, root: state.workspaceRoot)
        let thread = AIChatThread(title: "Explain what this code does", messages: DemoChatScript.messages(attachments))
        AIChatStore.shared.restore([thread], current: thread.id)
        if pending {
            AIChatStore.shared.attach([AIChatContext.file(document: document, text: view.string, root: state.workspaceRoot)])
            AIChatStore.shared.input = "Can record take a &str without allocating?"
        }
        state.showChat(focus: false)
    }

    private static func stageGhost(_ state: AppState, anchor: String, typed: String, text: String) {
        let e = SelfTestEditor(state: state)
        e.activate()
        e.place(on: anchor, atEnd: true)
        e.type(typed)
        guard let view = e.view else {
            return
        }
        CompletionSession.shared.hide()
        AIInlineController.shared.present(AIInlineGhost(anchor: view.selectedRange().location, text: text), in: view)
    }

    private static func ghostVisionStaged(_ state: AppState) -> Bool {
        guard visionStaged(state), let view = EditorPanes.shared.focusedView else {
            return false
        }
        if view.inlineGhost != nil {
            return true
        }
        let e = SelfTestEditor(state: state)
        e.activate()
        e.place(on: DemoChatScript.visionAnchor, atEnd: true)
        AIInlineController.shared.present(AIInlineGhost(anchor: view.selectedRange().location, text: DemoChatScript.visionGhost), in: view)
        return false
    }
}
