struct OutlineNode: Identifiable, Equatable {
    let id: String
    let name: String
    let kindLabel: String
    let startByte: UInt32
    let depth: Int
    var hasChildren = false
}

enum OutlineTree {
    static let scopeKind = "impl"

    private struct Entry {
        let name: String
        let kindLabel: String
        let startByte: UInt32
        let endByte: UInt32
        let isScope: Bool
    }

    static func nodes(_ rows: [OutlineRow]) -> [OutlineNode] {
        var nodes: [OutlineNode] = []
        var stack: [(end: UInt32, id: String)] = []
        var taken: Set<String> = []
        for entry in entries(rows) {
            while let top = stack.last, entry.startByte >= top.end {
                stack.removeLast()
            }
            let id = unique("\(stack.last?.id ?? "")/\(entry.kindLabel) \(entry.name)", in: &taken)
            if !nodes.isEmpty, nodes[nodes.count - 1].depth < stack.count {
                nodes[nodes.count - 1].hasChildren = true
            }
            nodes.append(OutlineNode(id: id, name: entry.name, kindLabel: entry.kindLabel, startByte: entry.startByte, depth: stack.count))
            stack.append((entry.endByte, id))
        }
        return nodes
    }

    static func visible(_ nodes: [OutlineNode], collapsed: Set<String>) -> [OutlineNode] {
        var hiddenBelow: Int?
        return nodes.filter { node in
            if let depth = hiddenBelow, node.depth > depth {
                return false
            }
            hiddenBelow = node.hasChildren && collapsed.contains(node.id) ? node.depth : nil
            return true
        }
    }

    private static func entries(_ rows: [OutlineRow]) -> [Entry] {
        var scopes: [UInt32: OutlineRow.Scope] = [:]
        for scope in rows.compactMap(\.scope) {
            scopes[scope.startByte] = scope
        }
        let items = rows.map { Entry(name: $0.name, kindLabel: $0.kindLabel, startByte: $0.startByte, endByte: $0.endByte, isScope: false) }
        let blocks = scopes.values.map { Entry(name: $0.label, kindLabel: scopeKind, startByte: $0.startByte, endByte: $0.endByte, isScope: true) }
        return (items + blocks).sorted { a, b in
            if a.startByte != b.startByte {
                return a.startByte < b.startByte
            }
            if a.endByte != b.endByte {
                return a.endByte > b.endByte
            }
            return a.isScope && !b.isScope
        }
    }

    private static func unique(_ base: String, in taken: inout Set<String>) -> String {
        var id = base
        var n = 1
        while !taken.insert(id).inserted {
            n += 1
            id = "\(base)#\(n)"
        }
        return id
    }
}
