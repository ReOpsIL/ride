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
