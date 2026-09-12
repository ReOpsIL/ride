import Foundation

extension DebugPanelModel {
    func reloadThreads() {
        load(key: "threads") { engine, id in
            (try? engine.debugThreads(sessionId: id)) ?? []
        } apply: { [weak self] list in
            self?.apply(threads: list)
        }
    }

    func reloadFrames(thread: Int64) {
        load(key: "frames.\(thread)") { engine, id in
            (try? engine.debugStack(sessionId: id, threadId: thread)) ?? []
        } apply: { [weak self] list in
            self?.apply(frames: list)
        }
    }

    func loadScopes(frame: Int64) {
        load(key: "scopes.\(frame)") { engine, id in
            (try? engine.debugScopes(sessionId: id, frameId: frame)) ?? []
        } apply: { [weak self] scopes in
            self?.applyScopes(scopes)
        }
    }

    func loadChildren(of node: VariableNode) {
        guard node.isExpandable else {
            return
        }
        let page = tree.nextPage(of: node.id)
        load(key: "children.\(node.id).\(page.start)") { engine, id in
            (try? engine.debugVariables(
                sessionId: id,
                variablesReference: node.reference,
                start: UInt32(page.start),
                count: UInt32(page.count)
            )) ?? []
        } apply: { [weak self] fetched in
            let nodes = fetched.enumerated().map { index, variable in
                DebugPanelModel.node(variable, parent: node.id, index: page.start + index)
            }
            self?.apply(children: nodes, of: node)
        }
    }

    func refreshWatches() {
        let expressions = watches.map(\.expression)
        guard !expressions.isEmpty, let frame = selectedFrame else {
            return
        }
        load(key: "watches.\(frame).\(expressions.joined(separator: "\u{1}"))") { engine, id in
            DebugPanelModel.evaluateAll(expressions, engine: engine, session: id, frame: frame)
        } apply: { [weak self] rows in
            self?.apply(watches: rows)
        }
    }

    func evaluate(
        _ expression: String,
        context: DebugEvaluateContext,
        completion: @escaping (WatchRow?) -> Void
    ) {
        guard let session = session(), let frame = selectedFrame else {
            completion(nil)
            return
        }
        let generation = stopGeneration
        DebugPanelModel.queue.async {
            let row = DebugPanelModel.evaluate(
                expression,
                engine: session.engine,
                session: session.id,
                frame: frame,
                context: context
            )
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isCurrent(generation) else {
                    completion(nil)
                    return
                }
                completion(row)
            }
        }
    }

    func applyScopes(_ scopes: [DebugScope]) {
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

    private func load<T>(
        key: String,
        work: @escaping (Engine, UInt64) -> T,
        apply: @escaping (T) -> Void
    ) {
        guard let session = session(), let generation = beginLoad(key) else {
            return
        }
        DebugPanelModel.queue.async {
            let value = work(session.engine, session.id)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.finishLoad(key, generation: generation) else {
                    return
                }
                apply(value)
            }
        }
    }

    private func session() -> (engine: Engine, id: UInt64)? {
        guard let engine = RideEngineClient.shared.engine, let id = DebugController.shared.sessionId else {
            return nil
        }
        return (engine, id)
    }
}
