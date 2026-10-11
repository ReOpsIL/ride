import CoreGraphics
import Foundation

enum MapKind: String, Equatable {
    case project
    case module
    case file
    case type
    case function
    case value
}

enum MapLink: String, Equatable {
    case depends
    case uses
}

struct MapNode: Identifiable, Equatable {
    var id: String
    var title: String
    var detail: String
    var kind: MapKind
    var path: String?
    var nested: MapGraph?
    var x: CGFloat = 0
    var y: CGFloat = 0

    var opens: Bool {
        nested?.nodes.isEmpty == false
    }
}

struct MapEdge: Identifiable, Equatable {
    var from: String
    var to: String
    var kind: MapLink

    var id: String { "\(from)>\(to)>\(kind.rawValue)" }
}

struct MapGraph: Equatable {
    var title: String
    var nodes: [MapNode]
    var edges: [MapEdge]

    static let empty = MapGraph(title: "", nodes: [], edges: [])

    var contentSize: CGSize {
        guard let maxX = nodes.map(\.x).max(), let maxY = nodes.map(\.y).max() else {
            return CGSize(width: 480, height: 320)
        }
        return CGSize(
            width: maxX + MapMetrics.nodeSize.width + MapMetrics.margin,
            height: maxY + MapMetrics.nodeSize.height + MapMetrics.margin
        )
    }

    func node(_ id: String) -> MapNode? {
        nodes.first { $0.id == id }
    }

    func origin(of id: String) -> CGPoint? {
        node(id).map { CGPoint(x: $0.x, y: $0.y) }
    }

    func anchor(of id: String, toward other: String) -> CGPoint? {
        guard let from = origin(of: id), let to = origin(of: other) else { return nil }
        let size = MapMetrics.nodeSize
        let dx = to.x - from.x
        let dy = to.y - from.y
        if abs(dx) >= abs(dy) {
            let x = dx >= 0 ? from.x + size.width : from.x
            return CGPoint(x: x, y: from.y + size.height / 2)
        }
        let y = dy >= 0 ? from.y + size.height : from.y
        return CGPoint(x: from.x + size.width / 2, y: y)
    }
}

enum MapMetrics {
    static let nodeSize = CGSize(width: 188, height: 84)
    static let margin: CGFloat = 32
    static let colGap: CGFloat = 64
    static let rowGap: CGFloat = 48
    static let minZoom: CGFloat = 0.25
    static let maxZoom: CGFloat = 2.5
}

enum MapNames {
    static func clean(_ raw: String) -> String {
        let collapsed = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let cut = collapsed.range(of: " where ").map { String(collapsed[..<$0.lowerBound]) } ?? collapsed
        let trimmed = cut.trimmingCharacters(in: .whitespaces)
        if trimmed.count > 60 {
            return String(trimmed.prefix(60))
        }
        return trimmed
    }
}
