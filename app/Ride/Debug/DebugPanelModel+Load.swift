import Foundation

extension DebugPanelModel {
    func reloadThreads() {
        guard let session = session() else {
            return
        }
        apply(threads: (try? session.engine.debugThreads(sessionId: session.id)) ?? [])
    }

    func reloadFrames(thread: Int64) {
        guard let session = session() else {
            return
        }
        apply(frames: (try? session.engine.debugStack(sessionId: session.id, threadId: thread)) ?? [])
    }

    func loadScopes(frame: Int64) {
        guard let session = session() else {
            return
        }
        let scopes = (try? session.engine.debugScopes(sessionId: session.id, frameId: frame)) ?? []
        let roots = scopes.enumerated().map { index, scope in
            VariableNode(
                id: VariableTree.childId(parent: VariableTree.rootId, index: index, name: scope.name),
                name: scope.name,
                value: "",
                typeName: nil,
                reference: scope.variablesReference,
                childrenCount: 0
            )
        }
        apply(roots: roots)
        guard let first = roots.first(where: { !$0.name.isEmpty }) else {
            return
        }
        expand(first)
        loadChildren(of: first)
    }

    func loadChildren(of node: VariableNode) {
        guard let session = session(), node.isExpandable else {
            return
        }
        let page = tree.nextPage(of: node.id)
        let fetched = (try? session.engine.debugVariables(
            sessionId: session.id,
            variablesReference: node.reference,
            start: UInt32(page.start),
            count: UInt32(page.count)
        )) ?? []
        let nodes = fetched.enumerated().map { index, variable in
            Self.node(variable, parent: node.id, index: page.start + index)
        }
        apply(children: nodes, of: node)
    }

    func refreshWatches() {
        guard !watches.isEmpty else {
            return
        }
        for row in watches {
            let result = evaluate(row.expression, context: .watch)
            setWatch(id: row.id, value: result.value, typeName: result.typeName, failed: result.failed)
        }
    }

    func evaluate(_ expression: String, context: DebugEvaluateContext) -> WatchRow {
        guard let session = session(), let frame = selectedFrame else {
            return WatchRow(id: expression, value: "not stopped", typeName: nil, failed: true)
        }
        do {
            let value = try session.engine.debugEvaluate(
                sessionId: session.id,
                frameId: frame,
                expression: expression,
                context: context
            )
            return WatchRow(id: expression, value: value.value, typeName: value.typeName, failed: false)
        } catch {
            return WatchRow(id: expression, value: "\(error)", typeName: nil, failed: true)
        }
    }

    static func node(_ variable: Variable, parent: String, index: Int) -> VariableNode {
        VariableNode(
            id: VariableTree.childId(parent: parent, index: index, name: variable.name),
            name: variable.name,
            value: variable.value,
            typeName: variable.typeName,
            reference: variable.variablesReference,
            childrenCount: Int(variable.childrenCount)
        )
    }

    private func session() -> (engine: Engine, id: UInt64)? {
        guard let engine = RideEngineClient.shared.engine, let id = DebugController.shared.sessionId else {
            return nil
        }
        return (engine, id)
    }
}
