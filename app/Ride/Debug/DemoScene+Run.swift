import AppKit

extension DemoScene {
    static let debugLine = 10

    static func running(_ name: String, state: AppState) -> Bool {
        switch name {
        case "targets":
            editor(state)
            DemoLaunch.after(1.4) { selectBinary(state) }
            ready(when: { !state.projectModel.rows.isEmpty })
        case "run":
            editor(state)
            DemoLaunch.after(1.6) { start(state, action: .run) }
            ready(when: { finished(state) })
        case "tests":
            editor(state)
            DemoLaunch.after(1.6) { start(state, action: .test) }
            ready(when: { finished(state) && !TestRunStore.shared.tree.rows.isEmpty })
        case "terminal":
            editor(state)
            DemoLaunch.after(1.4) { state.newTerminal() }
            ready(after: 3.0)
        case "debug":
            editor(state, line: debugLine)
            DemoLaunch.after(1.6) { startDebug(state) }
            ready(when: { state.debug.isStopped && state.debugPanel.tree.rows.contains { $0.depth > 0 } }, timeout: 180)
        default:
            return false
        }
        return true
    }

    private static func finished(_ state: AppState) -> Bool {
        !state.runOutput.isRunning && state.runOutput.status != nil
    }

    private static func selectBinary(_ state: AppState) {
        state.selectTarget(state.projectModel.rows.first { $0.kind == .bin } ?? state.projectModel.rows.first)
    }

    private static func start(_ state: AppState, action: RunAction) {
        selectBinary(state)
        state.runAction(action)
    }

    private static func startDebug(_ state: AppState) {
        let e = SelfTestEditor(state: state)
        e.focus()
        e.caret(line: debugLine)
        state.toggleBreakpointAtCaret()
        selectBinary(state)
        state.startDebug()
        expandLocals(state)
    }

    private static func expandLocals(_ state: AppState, attempt: Int = 0) {
        guard attempt < 120 else {
            return
        }
        guard state.debug.isStopped, !state.debugPanel.tree.rows.isEmpty else {
            DemoLaunch.after(1.0) { expandLocals(state, attempt: attempt + 1) }
            return
        }
        state.debugPanel.visible = true
        state.debugPanel.addWatch("counter")
        for row in state.debugPanel.tree.rows where row.depth == 0 && !row.expanded {
            state.debugPanel.toggle(row)
        }
    }
}
