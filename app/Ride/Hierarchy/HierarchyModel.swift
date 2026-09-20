import Foundation

enum HierarchyMode: String, Equatable, CaseIterable {
    case callers
    case callees
    case types
}

struct HierarchyNode: Equatable, Identifiable {
    let id: String
    let cycleKey: String
    let name: String
    let kindLabel: String
    let path: String
    let line: UInt32
    let byte: UInt32

    init(parent: String, name: String, kindLabel: String, path: String, line: UInt32, byte: UInt32) {
        cycleKey = "\(path):\(byte)"
        id = parent.isEmpty ? cycleKey : "\(parent)/\(cycleKey)"
        self.name = name
        self.kindLabel = kindLabel
        self.path = path
        self.line = line
        self.byte = byte
    }
}

struct HierarchyRow: Equatable, Identifiable {
    let node: HierarchyNode
    let depth: Int
    let expanded: Bool
    let expandable: Bool

    var id: String {
        node.id
    }
}

struct HierarchyModel: Equatable {
    static let maxDepth = 6

    var mode: HierarchyMode = .callers
    var running = false
    var finished = false
    private(set) var generation = 0
    private(set) var root: HierarchyNode?
    private var children: [String: [HierarchyNode]] = [:]
    private var expanded: Set<String> = []
    private var parent: [String: String] = [:]

    var rootName: String {
        root?.name ?? ""
    }

    var childCount: Int {
        guard let root else {
            return 0
        }
        return loaded(root.id).count
    }

    mutating func begin(_ mode: HierarchyMode) -> Int {
        generation += 1
        self.mode = mode
        running = true
        finished = false
        root = nil
        children = [:]
        expanded = []
        parent = [:]
        return generation
    }

    mutating func finishEmpty() {
        root = nil
        children = [:]
        expanded = []
        parent = [:]
        running = false
        finished = true
    }

    mutating func setRoot(_ node: HierarchyNode, children incoming: [HierarchyNode]) {
        root = node
        expanded = [node.id]
        parent = [:]
        children = [node.id: Self.guarded(incoming, ancestors: [node.cycleKey])]
        for child in children[node.id] ?? [] {
            parent[child.id] = node.id
        }
        running = false
        finished = true
    }

    func loaded(_ id: String) -> [HierarchyNode] {
        children[id] ?? []
    }

    func isExpanded(_ id: String) -> Bool {
        expanded.contains(id)
    }

    func isLoaded(_ id: String) -> Bool {
        children[id] != nil
    }

    func isCurrent(_ generation: Int) -> Bool {
        self.generation == generation
    }

    func node(id: String) -> HierarchyNode? {
        if root?.id == id {
            return root
        }
        for list in children.values {
            if let found = list.first(where: { $0.id == id }) {
                return found
            }
        }
        return nil
    }

    @discardableResult
    mutating func expand(_ id: String) -> Bool {
        guard mode != .callees else {
            return false
        }
        guard let depth = rows.first(where: { $0.id == id })?.depth, depth < Self.maxDepth else {
            return false
        }
        expanded.insert(id)
        return children[id] == nil
    }

    mutating func collapse(_ id: String) {
        expanded.remove(id)
    }

    mutating func attach(_ incoming: [HierarchyNode], to id: String) {
        let keys = ancestorKeys(id)
        let filtered = Self.guarded(incoming, ancestors: keys)
        children[id] = filtered
        for child in filtered {
            parent[child.id] = id
        }
    }

    var rows: [HierarchyRow] {
        guard let root else {
            return []
        }
        var out: [HierarchyRow] = []
        walk(node: root, depth: 0, into: &out)
        return out
    }

    private func walk(node: HierarchyNode, depth: Int, into out: inout [HierarchyRow]) {
        let open = expanded.contains(node.id)
        let expandable = mode != .callees && depth < Self.maxDepth
        out.append(HierarchyRow(node: node, depth: depth, expanded: open, expandable: expandable))
        guard open, depth < Self.maxDepth else {
            return
        }
        for child in loaded(node.id) {
            walk(node: child, depth: depth + 1, into: &out)
        }
    }

    private func ancestorKeys(_ id: String) -> [String] {
        var keys: [String] = []
        if let node = node(id: id) {
            keys.append(node.cycleKey)
        }
        var at = parent[id]
        while let current = at {
            if let node = node(id: current) {
                keys.append(node.cycleKey)
            }
            at = parent[current]
        }
        return keys
    }

    static func guarded(_ nodes: [HierarchyNode], ancestors: [String]) -> [HierarchyNode] {
        var seen = Set(ancestors)
        var out: [HierarchyNode] = []
        for node in nodes where seen.insert(node.cycleKey).inserted {
            out.append(node)
        }
        return out
    }
}
