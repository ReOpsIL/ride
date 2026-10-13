import CoreGraphics
import Foundation

enum MapArrange: Equatable {
    case fruchtermanReingold
    case kamadaKawai
    case sugiyama

    func apply(_ graph: MapGraph) -> MapGraph {
        switch self {
        case .fruchtermanReingold: MapFruchterman.apply(graph)
        case .kamadaKawai: MapStress.apply(graph)
        case .sugiyama: MapSugiyama.apply(graph)
        }
    }
}

enum MapSpread {
    static var length: CGFloat {
        MapMetrics.nodeSize.width + MapMetrics.colGap
    }

    static var box: CGSize {
        CGSize(
            width: MapMetrics.nodeSize.width + MapMetrics.colGap,
            height: MapMetrics.nodeSize.height + MapMetrics.rowGap
        )
    }

    static func index(_ graph: MapGraph) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1.id, $0) })
    }

    static func seeds(_ graph: MapGraph) -> [CGPoint] {
        let points = graph.nodes.map { CGPoint(x: $0.x, y: $0.y) }
        return collapsed(points) ? circle(points.count) : points
    }

    static func finish(_ graph: MapGraph, _ layout: (MapGraph) -> [CGPoint]) -> MapGraph {
        guard graph.nodes.count > 1 else { return graph }
        let groups = components(graph)
        guard let major = groups.first, major.count > 1 else {
            return placed(graph, seeds(graph))
        }
        guard groups.count > 1 else {
            return placed(graph, layout(graph))
        }
        let core = layout(subgraph(graph, major))
        var points = Array(repeating: CGPoint.zero, count: graph.nodes.count)
        for (offset, index) in major.enumerated() where offset < core.count {
            points[index] = core[offset]
        }
        tuck(&points, major: major, satellites: groups.dropFirst().flatMap { $0 })
        return placed(graph, points)
    }

    static func placed(_ graph: MapGraph, _ points: [CGPoint]) -> MapGraph {
        let shifted = packed(points)
        var copy = graph
        for index in copy.nodes.indices where index < shifted.count {
            copy.nodes[index].x = shifted[index].x
            copy.nodes[index].y = shifted[index].y
        }
        return copy
    }

    static func packed(_ input: [CGPoint]) -> [CGPoint] {
        let points = separated(input)
        guard let minX = points.map(\.x).min(), let minY = points.map(\.y).min() else { return points }
        let dx = MapMetrics.margin - minX
        let dy = MapMetrics.margin - minY
        return points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
    }

    static func separated(_ input: [CGPoint]) -> [CGPoint] {
        var points = input
        let box = box
        guard points.count > 1 else { return points }
        for _ in 0..<80 {
            var moved = false
            for i in points.indices {
                for j in points.indices where j > i {
                    var dx = points[j].x - points[i].x
                    var dy = points[j].y - points[i].y
                    if dx == 0, dy == 0 {
                        dx = 1
                        dy = CGFloat((j - i) % 2 == 0 ? 1 : -1)
                    }
                    let overlapX = box.width - abs(dx)
                    let overlapY = box.height - abs(dy)
                    guard overlapX > 0, overlapY > 0 else { continue }
                    moved = true
                    if overlapX <= overlapY {
                        let push = overlapX / 2 + 0.5
                        let sign: CGFloat = dx > 0 ? 1 : -1
                        points[i].x -= sign * push
                        points[j].x += sign * push
                    } else {
                        let push = overlapY / 2 + 0.5
                        let sign: CGFloat = dy > 0 ? 1 : -1
                        points[i].y -= sign * push
                        points[j].y += sign * push
                    }
                }
            }
            if !moved { break }
        }
        return points
    }

    private static func components(_ graph: MapGraph) -> [[Int]] {
        let index = index(graph)
        var adjacent = Array(repeating: [Int](), count: graph.nodes.count)
        for edge in graph.edges {
            guard let from = index[edge.from], let to = index[edge.to], from != to else { continue }
            adjacent[from].append(to)
            adjacent[to].append(from)
        }
        var seen = Array(repeating: false, count: graph.nodes.count)
        var groups: [[Int]] = []
        for start in graph.nodes.indices where !seen[start] {
            var group: [Int] = []
            var stack = [start]
            seen[start] = true
            while let node = stack.popLast() {
                group.append(node)
                for next in adjacent[node] where !seen[next] {
                    seen[next] = true
                    stack.append(next)
                }
            }
            groups.append(group)
        }
        return groups.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return (lhs.min() ?? 0) < (rhs.min() ?? 0)
        }
    }

    private static func subgraph(_ graph: MapGraph, _ indexes: [Int]) -> MapGraph {
        let nodes = indexes.map { graph.nodes[$0] }
        let ids = Set(nodes.map(\.id))
        let edges = graph.edges.filter { ids.contains($0.from) && ids.contains($0.to) }
        return MapGraph(title: graph.title, nodes: nodes, edges: edges)
    }

    private static func tuck(_ points: inout [CGPoint], major: [Int], satellites: [Int]) {
        guard !satellites.isEmpty, !major.isEmpty else { return }
        let node = MapMetrics.nodeSize
        let strideW = box.width
        let strideH = box.height
        let minX = major.map { points[$0].x }.min() ?? 0
        let maxX = major.map { points[$0].x }.max() ?? 0
        let maxY = major.map { points[$0].y }.max() ?? 0
        let width = maxX - minX + node.width
        let alongGroup = max(1, Int((width / strideW).rounded()))
        let square = max(1, Int((Double(satellites.count) * Double(strideH / strideW)).squareRoot().rounded()))
        let columns = min(satellites.count, max(alongGroup, square))
        let blockWidth = CGFloat(columns - 1) * strideW + node.width
        let originX = minX + (width - blockWidth) / 2
        let originY = maxY + node.height + MapMetrics.rowGap
        for (offset, index) in satellites.enumerated() {
            points[index] = CGPoint(
                x: originX + CGFloat(offset % columns) * strideW,
                y: originY + CGFloat(offset / columns) * strideH
            )
        }
    }

    private static func collapsed(_ points: [CGPoint]) -> Bool {
        guard let first = points.first else { return false }
        return points.allSatisfy { hypot($0.x - first.x, $0.y - first.y) < 1 }
    }

    private static func circle(_ count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        let radius = length * max(CGFloat(count) / (2 * .pi), 1)
        return (0..<count).map { index in
            let angle = CGFloat(index) / CGFloat(max(count, 1)) * 2 * .pi
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
    }
}
