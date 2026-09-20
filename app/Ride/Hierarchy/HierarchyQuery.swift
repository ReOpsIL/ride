import Foundation

enum HierarchyQuery {
    struct Root {
        let root: HierarchyNode
        let children: [HierarchyNode]
    }

    static func root(
        engine: Engine,
        mode: HierarchyMode,
        sessionId: UInt64,
        path: String,
        line: UInt32,
        byte: UInt32,
        outline: [OutlineRow]
    ) -> Root? {
        let enclosing = outline.last { $0.startByte <= byte && byte < $0.endByte }
        switch mode {
        case .callers:
            let response = engine.callers(sessionId: sessionId, cursorByte: byte)
            return makeRoot(response.name, kind: enclosing?.kindLabel ?? "fn", path: path, line: line, byte: byte) {
                callerNodes(response.hits, parent: $0)
            }
        case .callees:
            let hits = engine.callees(sessionId: sessionId, cursorByte: byte)
            return makeRoot(enclosing?.name ?? "", kind: enclosing?.kindLabel ?? "fn", path: path, line: line, byte: byte) { parent in
                hits.map {
                    HierarchyNode(parent: parent, name: $0.name, kindLabel: "fn", path: path, line: $0.line, byte: $0.byteStart)
                }
            }
        case .types:
            let response = engine.typeHierarchy(sessionId: sessionId, cursorByte: byte)
            let kind = outline.first { $0.name == response.name }?.kindLabel ?? "type"
            return makeRoot(response.name, kind: kind, path: path, line: line, byte: byte) {
                typeNodes(response, parent: $0)
            }
        }
    }

    struct OpenBuffer {
        let sessionId: UInt64
        let rows: [OutlineRow]
    }

    static func locate(_ path: String, buffers: [BufferDocument], workspace: URL?) -> (file: String, open: OpenBuffer?) {
        let file = resolved(path, workspace: workspace)
        let open = buffers.first { matches($0, path: path, file: file) }.flatMap { document in
            document.sessionId.map { OpenBuffer(sessionId: $0, rows: document.outline) }
        }
        return (file, open)
    }

    static func children(
        engine: Engine,
        mode: HierarchyMode,
        node: HierarchyNode,
        file: String,
        open: OpenBuffer?
    ) -> [HierarchyNode] {
        switch mode {
        case .callers:
            return withSession(engine, file: file, open: open) { session in
                let at = session.expandByte(name: node.name, byte: node.byte)
                return callerNodes(engine.callers(sessionId: session.id, cursorByte: at).hits, parent: node.id)
            }
        case .types:
            return withSession(engine, file: file, open: open) { session in
                typeNodes(engine.typeHierarchy(sessionId: session.id, cursorByte: node.byte), parent: node.id)
            }
        case .callees:
            return []
        }
    }

    private static func makeRoot(
        _ name: String,
        kind: String,
        path: String,
        line: UInt32,
        byte: UInt32,
        children: (String) -> [HierarchyNode]
    ) -> Root? {
        guard !name.isEmpty else {
            return nil
        }
        let root = HierarchyNode(parent: "", name: name, kindLabel: kind, path: path, line: line, byte: byte)
        return Root(root: root, children: children(root.id))
    }

    private static func callerNodes(_ hits: [UsageHit], parent: String) -> [HierarchyNode] {
        hits.map {
            HierarchyNode(
                parent: parent,
                name: $0.enclosingItem.isEmpty ? $0.path : $0.enclosingItem,
                kindLabel: SessionService.kindLabel($0.enclosingKind),
                path: $0.path,
                line: $0.line,
                byte: $0.byteStart
            )
        }
    }

    private static func typeNodes(_ response: TypeHierarchy, parent: String) -> [HierarchyNode] {
        (response.supertypes + response.subtypes).map {
            HierarchyNode(
                parent: parent,
                name: $0.name,
                kindLabel: SessionService.kindLabel($0.kind),
                path: $0.path,
                line: 0,
                byte: $0.byteStart
            )
        }
    }

    private static func withSession(
        _ engine: Engine,
        file: String,
        open: OpenBuffer?,
        work: (HierarchySession) -> [HierarchyNode]
    ) -> [HierarchyNode] {
        guard let session = openSession(engine, file: file, open: open) else {
            return []
        }
        let nodes = work(session)
        session.close(engine)
        return nodes
    }

    private static func openSession(_ engine: Engine, file: String, open: OpenBuffer?) -> HierarchySession? {
        if let open {
            return HierarchySession(id: open.sessionId, owned: false, rows: open.rows)
        }
        let text = (try? String(contentsOfFile: file, encoding: .utf8)) ?? ""
        guard let opened = try? engine.openSession(bufferId: UUID().uuidString, path: file, text: text, visible: nil) else {
            return nil
        }
        return HierarchySession(id: opened.sessionId, owned: true, items: opened.update.outline ?? [])
    }

    private static func resolved(_ path: String, workspace: URL?) -> String {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL.path
        }
        if let workspace {
            return workspace.appendingPathComponent(path).standardizedFileURL.path
        }
        return path
    }

    private static func matches(_ document: BufferDocument, path: String, file: String) -> Bool {
        guard let url = document.fileURL?.standardizedFileURL else {
            return false
        }
        return url.path == file || url.path == path || url.path.hasSuffix("/\(path)")
    }
}
