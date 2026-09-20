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

    static func children(
        engine: Engine,
        mode: HierarchyMode,
        node: HierarchyNode,
        buffers: [BufferDocument],
        workspace: URL?
    ) -> [HierarchyNode] {
        switch mode {
        case .callers:
            return withSession(engine, path: node.path, buffers: buffers, workspace: workspace) { session in
                let at = session.expandByte(name: node.name, byte: node.byte)
                return callerNodes(engine.callers(sessionId: session.id, cursorByte: at).hits, parent: node.id)
            }
        case .types:
            return withSession(engine, path: node.path, buffers: buffers, workspace: workspace) { session in
                return typeNodes(engine.typeHierarchy(sessionId: session.id, cursorByte: node.byte), parent: node.id)
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
        path: String,
        buffers: [BufferDocument],
        workspace: URL?,
        work: (HierarchySession) -> [HierarchyNode]
    ) -> [HierarchyNode] {
        guard let session = openSession(engine, path: path, buffers: buffers, workspace: workspace) else {
            return []
        }
        let nodes = work(session)
        session.close(engine)
        return nodes
    }

    private static func openSession(
        _ engine: Engine,
        path: String,
        buffers: [BufferDocument],
        workspace: URL?
    ) -> HierarchySession? {
        let file = resolved(path, workspace: workspace)
        if let document = buffers.first(where: { matches($0, path: path, file: file) }), let id = document.sessionId {
            return HierarchySession(id: id, owned: false, rows: document.outline)
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

private struct HierarchySession {
    let id: UInt64
    let owned: Bool
    let names: [String]
    let start: [UInt32]
    let end: [UInt32]
    let nameStart: [UInt32]

    init(id: UInt64, owned: Bool, rows: [OutlineRow]) {
        self.id = id
        self.owned = owned
        names = rows.map(\.name)
        start = rows.map(\.startByte)
        end = rows.map(\.endByte)
        nameStart = rows.map(\.startByte)
    }

    init(id: UInt64, owned: Bool, items: [OutlineItem]) {
        self.id = id
        self.owned = owned
        names = items.map(\.name)
        start = items.map(\.startByte)
        end = items.map(\.endByte)
        nameStart = items.map(\.nameStartByte)
    }

    func close(_ engine: Engine) {
        if owned {
            engine.closeSession(sessionId: id)
        }
    }

    func expandByte(name: String, byte: UInt32) -> UInt32 {
        var best: (size: UInt32, at: UInt32)?
        for index in start.indices where start[index] <= byte && byte < end[index] {
            if !name.isEmpty && names[index] != name {
                continue
            }
            let size = end[index] - start[index]
            if best.map({ size < $0.size }) ?? true {
                best = (size, nameStart[index])
            }
        }
        return best?.at ?? byte
    }
}
