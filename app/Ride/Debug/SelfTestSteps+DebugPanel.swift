import AppKit

extension SelfTestSteps {
    static func debugPanelSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        [panelToggle(state: state, e: e), watchPersists(state: state, e: e)]
    }

    private static func panelToggle(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "debug panel toggle", wait: 0.4, run: {
            if state.debugPanel.visible {
                state.toggleDebugPanel()
            }
            state.toggleDebugPanel()
        }, check: {
            e.expect(state.debugPanel.visible, "panel hidden")
        })
    }

    private static func watchPersists(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "debug watch persists", wait: 0.4, run: {
            state.debugPanel.addWatch("counter")
        }, check: {
            guard let data = try? JSONEncoder().encode(state.captureWorkspace()),
                  let loaded = WorkspaceState.decode(data)
            else {
                return "watches did not round trip"
            }
            let saved = loaded.watches
            state.debugPanel.removeWatch(id: "counter")
            state.toggleDebugPanel()
            return e.expect(
                saved == ["counter"] && state.debugPanel.expressions.isEmpty && !state.debugPanel.visible,
                "watches \(saved) left \(state.debugPanel.expressions)"
            )
        })
    }

    static func panelLoadsVariables(state: AppState, e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "debug panel loads variables", wait: 0.3, until: { state.debugPanel.tree.rows.count > 1 }, timeout: 30, run: {}, check: {
            let rows = state.debugPanel.tree.rows
            let scope = rows.first(where: \.expanded)
            let children = rows.dropFirst().filter { $0.depth == 1 }
            return e.expect(
                state.debugPanel.visible && state.debugPanel.selectedFrame != nil && scope?.expanded == true && !children.isEmpty,
                "visible \(state.debugPanel.visible) frame \(String(describing: state.debugPanel.selectedFrame)) rows \(rows.map(\.node.name))"
            )
        })
    }
}
