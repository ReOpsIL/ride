import AppKit

extension DemoScene {
    static let cppDebugBody = "return PI * radius_ * radius_;"

    static func cppDebug(_ name: String, state: AppState) -> Bool {
        guard name == "cppdebug" else {
            return false
        }
        editor(state, file: "src/shapes.cpp", line: 22)
        guard DeveloperMode.isEnabled else {
            print("cppdebug skipped: macOS developer mode is disabled")
            ready(after: 2.0)
            return true
        }
        let stage = DemoStage()
        DemoLaunch.after(1.8) { startCppDebug(state) }
        ready(when: { cppDebugStaged(state, stage: stage) }, timeout: 360)
        return true
    }

    private static func startCppDebug(_ state: AppState) {
        let e = SelfTestEditor(state: state)
        e.focus()
        e.place(on: cppDebugBody)
        state.toggleBreakpointAtCaret()
        selectBinary(state)
        state.startDebug()
    }

    private static func cppDebugStaged(_ state: AppState, stage: DemoStage) -> Bool {
        guard state.debug.isStopped, !state.debugPanel.tree.rows.isEmpty else {
            return false
        }
        stageDebugPanel(state)
        if !stage.typed {
            selectMainFrame(state)
            stage.typed = true
            return false
        }
        guard let node = vectorLocal(state) else {
            return false
        }
        if state.debugPanel.tree.isLoaded(node.id) {
            return true
        }
        if !state.debugPanel.tree.isExpanded(node.id) {
            state.debugPanel.toggle(VariableRow(node: node, depth: 1, expanded: false))
        }
        return false
    }

    private static func selectMainFrame(_ state: AppState) {
        guard let frame = state.debugPanel.frames.first(where: { $0.name.contains("main") }) else {
            return
        }
        state.debugPanel.selectFrame(frame.id, jump: false)
    }

    private static func vectorLocal(_ state: AppState) -> VariableNode? {
        state.debugPanel.tree.rows.first { $0.node.typeName?.contains("vector") == true }?.node
    }
}
