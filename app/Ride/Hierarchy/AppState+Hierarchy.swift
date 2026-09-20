import Foundation

extension AppState {
    func showCallHierarchy() {
        queryHierarchy(.callers)
    }

    func showTypeHierarchy() {
        queryHierarchy(.types)
    }

    func setHierarchyMode(_ mode: HierarchyMode) {
        queryHierarchy(mode)
    }

    func hideHierarchy() {
        showHierarchy = false
    }

    func openHierarchyRow(_ node: HierarchyNode) {
        if node.path.isEmpty {
            jumpTo(byte: node.byte)
            return
        }
        openUsage(path: node.path, byte: node.byte)
    }

    func toggleHierarchyRow(_ id: String) {
        if hierarchy.isExpanded(id) {
            hierarchy.collapse(id)
            return
        }
        guard hierarchy.expand(id), let node = hierarchy.node(id: id) else {
            return
        }
        loadHierarchyChildren(node)
    }

    private func hierarchyTarget() -> (view: RideTextView, document: BufferDocument, sessionId: UInt64)? {
        if let (view, document) = focusedEditor, let sessionId = document.sessionId {
            return (view, document, sessionId)
        }
        if let document = activeBuffer, let sessionId = document.sessionId, let view = editorView(for: document) {
            return (view, document, sessionId)
        }
        return nil
    }

    private func queryHierarchy(_ mode: HierarchyMode) {
        showHierarchy = true
        let generation = hierarchy.begin(mode)
        guard let target = hierarchyTarget() else {
            hierarchy.finishEmpty()
            return
        }
        let text = target.view.string
        let byte = UInt32(Utf16.utf8Offset(in: text, utf16: target.view.selectedRange().location))
        let path = target.document.fileURL?.standardizedFileURL.path ?? ""
        let line = UInt32(max(1, cursorLine))
        let outline = target.document.outline
        let sessionId = target.sessionId
        let started = RideEngineClient.shared.withEngine({ engine in
            _ = try? engine.setText(sessionId: sessionId, text: text, visible: nil)
            _ = try? engine.noteSaved(sessionId: sessionId)
            return HierarchyQuery.root(
                engine: engine,
                mode: mode,
                sessionId: sessionId,
                path: path,
                line: line,
                byte: byte,
                outline: outline
            )
        }, then: { [weak self] result in
            guard let self, self.hierarchy.isCurrent(generation) else {
                return
            }
            if let result {
                self.hierarchy.setRoot(result.root, children: result.children)
            } else {
                self.hierarchy.finishEmpty()
            }
        })
        if !started {
            hierarchy.finishEmpty()
        }
    }

    private func loadHierarchyChildren(_ node: HierarchyNode) {
        let generation = hierarchy.generation
        let mode = hierarchy.mode
        let started = RideEngineClient.shared.withEngine({ [weak self] engine in
            guard let self else {
                return [HierarchyNode]()
            }
            return HierarchyQuery.children(
                engine: engine,
                mode: mode,
                node: node,
                buffers: self.buffers,
                workspace: self.workspaceRoot
            )
        }, then: { [weak self] nodes in
            guard let self, self.hierarchy.isCurrent(generation) else {
                return
            }
            self.hierarchy.attach(nodes, to: node.id)
        })
        if !started {
            hierarchy.attach([], to: node.id)
        }
    }
}
