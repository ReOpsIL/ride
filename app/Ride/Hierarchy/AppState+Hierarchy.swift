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
        HierarchyFollower.shared.anchored(nil)
    }

    func followHierarchy() {
        queryHierarchy(hierarchy.mode, follow: true)
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

    private func hierarchyTarget() -> (view: RideTextView, document: BufferDocument)? {
        if let (view, document) = focusedEditor, document.sessionId != nil {
            return (view, document)
        }
        if let document = activeBuffer, document.sessionId != nil, let view = editorView(for: document) {
            return (view, document)
        }
        return nil
    }

    private func queryHierarchy(_ mode: HierarchyMode, follow: Bool = false) {
        showHierarchy = true
        let generation = follow ? hierarchy.beginRefresh() : hierarchy.begin(mode)
        guard let target = hierarchyTarget() else {
            finishWithout(follow: follow)
            return
        }
        HierarchyFollower.shared.anchored(HierarchyFollower.key(document: target.document, view: target.view))
        let text = target.view.string
        let byte = UInt32(Utf16.utf8Offset(in: text, utf16: target.view.selectedRange().location))
        let path = target.document.fileURL?.standardizedFileURL.path ?? ""
        let line = UInt32(max(1, cursorLine))
        let outline = target.document.outline
        let started = SessionService.shared.read(target.document, lane: .workspace, { engine, sessionId in
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
                self.finishWithout(follow: follow)
            }
        })
        if !started {
            finishWithout(follow: follow)
        }
    }

    private func finishWithout(follow: Bool) {
        if follow {
            hierarchy.finishUnchanged()
        } else {
            hierarchy.finishEmpty()
        }
    }

    private func loadHierarchyChildren(_ node: HierarchyNode) {
        let generation = hierarchy.generation
        let mode = hierarchy.mode
        let (file, open) = HierarchyQuery.locate(node.path, buffers: buffers, workspace: workspaceRoot)
        let started = RideEngineClient.shared.withEngine({ engine in
            HierarchyQuery.children(engine: engine, mode: mode, node: node, file: file, open: open)
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
