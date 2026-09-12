import Foundation

struct VariableNode: Identifiable, Equatable {
    let id: String
    let name: String
    let value: String
    let typeName: String?
    let reference: Int64
    let childrenCount: Int

    init(id: String, name: String, value: String, typeName: String? = nil, reference: Int64 = 0, childrenCount: Int = 0) {
        self.id = id
        self.name = name
        self.value = value
        self.typeName = typeName
        self.reference = reference
        self.childrenCount = childrenCount
    }

    var isExpandable: Bool {
        reference != 0
    }
}

struct VariableRow: Identifiable, Equatable {
    let node: VariableNode
    let depth: Int
    let expanded: Bool

    var id: String {
        node.id
    }
}

struct VariableTree: Equatable {
    static let pageSize = 100
    static let rootId = ""

    private var children: [String: [VariableNode]] = [:]
    private var expanded: Set<String> = []
    private var complete: Set<String> = []

    mutating func clear() {
        children = [:]
        expanded = []
        complete = []
    }

    func isLoaded(_ id: String) -> Bool {
        children[id] != nil
    }

    func isExpanded(_ id: String) -> Bool {
        expanded.contains(id)
    }

    func loaded(_ id: String) -> [VariableNode] {
        children[id] ?? []
    }

    func hasMore(_ id: String) -> Bool {
        isLoaded(id) && !complete.contains(id)
    }

    func nextPage(of id: String) -> (start: Int, count: Int) {
        (loaded(id).count, Self.pageSize)
    }

    mutating func replace(_ nodes: [VariableNode], of id: String, expected: Int = 0) {
        children[id] = []
        complete.remove(id)
        append(nodes, to: id, expected: expected)
    }

    mutating func append(_ nodes: [VariableNode], to id: String, expected: Int = 0) {
        var merged = loaded(id)
        let known = Set(merged.map(\.id))
        merged.append(contentsOf: nodes.filter { !known.contains($0.id) })
        children[id] = merged
        if nodes.count < Self.pageSize || (expected > 0 && merged.count >= expected) {
            complete.insert(id)
        }
    }

    @discardableResult
    mutating func toggle(_ id: String) -> Bool {
        guard expanded.contains(id) else {
            expanded.insert(id)
            return true
        }
        expanded.remove(id)
        return false
    }

    mutating func collapse(_ id: String) {
        expanded.remove(id)
    }

    var rows: [VariableRow] {
        var out: [VariableRow] = []
        walk(id: Self.rootId, depth: 0, into: &out)
        return out
    }

    func node(id: String) -> VariableNode? {
        for (_, nodes) in children {
            if let found = nodes.first(where: { $0.id == id }) {
                return found
            }
        }
        return nil
    }

    static func childId(parent: String, index: Int, name: String) -> String {
        "\(parent)/\(index).\(name)"
    }

    private func walk(id: String, depth: Int, into out: inout [VariableRow]) {
        for node in loaded(id) {
            let open = expanded.contains(node.id)
            out.append(VariableRow(node: node, depth: depth, expanded: open))
            guard open else {
                continue
            }
            walk(id: node.id, depth: depth + 1, into: &out)
        }
    }
}
