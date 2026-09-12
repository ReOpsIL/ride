import AppKit

extension SelfTestSteps {
    static func debugPanelSteps(state: AppState, e: SelfTestEditor) -> [SelfTestStep] {
        [panelToggle(state: state, e: e), watchPersists(state: state, e: e), variableTree(e: e)]
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

    private static func variableTree(e: SelfTestEditor) -> SelfTestStep {
        SelfTestStep(name: "debug variable tree pages", wait: 0.2, run: {}, check: {
            var tree = VariableTree()
            let root = VariableNode(id: "locals", name: "Locals", value: "", reference: 7, childrenCount: 150)
            tree.replace([root], of: VariableTree.rootId)
            tree.toggle(root.id)
            tree.append(page(0, parent: root.id, count: VariableTree.pageSize), to: root.id, expected: 150)
            let paged = tree.hasMore(root.id) && tree.rows.count == 1 + VariableTree.pageSize
            tree.append(page(VariableTree.pageSize, parent: root.id, count: 50), to: root.id, expected: 150)
            return e.expect(
                paged && !tree.hasMore(root.id) && tree.rows.count == 151,
                "rows \(tree.rows.count) more \(tree.hasMore(root.id))"
            )
        })
    }

    private static func page(_ start: Int, parent: String, count: Int) -> [VariableNode] {
        (start ..< start + count).map { index in
            VariableNode(
                id: VariableTree.childId(parent: parent, index: index, name: "item"),
                name: "item\(index)",
                value: "\(index)"
            )
        }
    }
}
