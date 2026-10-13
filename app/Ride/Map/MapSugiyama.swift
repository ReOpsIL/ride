import CoreGraphics
import Foundation

enum MapSugiyama {
    static func apply(_ graph: MapGraph) -> MapGraph {
        MapSpread.finish(graph, positions)
    }

    static func positions(_ graph: MapGraph) -> [CGPoint] {
        let count = graph.nodes.count
        guard count > 1 else { return MapSpread.seeds(graph) }
        let forward = acyclic(count, directed(graph))
        let model = layered(count, forward)
        let swept = sweep(model)
        return coordinates(count, swept.rows, swept.neighbors)
    }

    private static func directed(_ graph: MapGraph) -> [(Int, Int)] {
        let index = MapSpread.index(graph)
        var seen: Set<String> = []
        var arcs: [(Int, Int)] = []
        for edge in graph.edges {
            guard let from = index[edge.from], let to = index[edge.to], from != to else { continue }
            guard seen.insert("\(from)>\(to)").inserted else { continue }
            arcs.append((from, to))
        }
        return arcs
    }

    private static func acyclic(_ count: Int, _ arcs: [(Int, Int)]) -> [(Int, Int)] {
        var outgoing = Array(repeating: [Int](), count: count)
        for (from, to) in arcs {
            outgoing[from].append(to)
        }
        var color = Array(repeating: 0, count: count)
        var back: Set<String> = []
        func walk(_ node: Int) {
            color[node] = 1
            for next in outgoing[node] {
                if color[next] == 1 {
                    back.insert("\(node)>\(next)")
                } else if color[next] == 0 {
                    walk(next)
                }
            }
            color[node] = 2
        }
        for node in 0..<count where color[node] == 0 {
            walk(node)
        }
        var seen: Set<String> = []
        var forward: [(Int, Int)] = []
        for (from, to) in arcs {
            let head = back.contains("\(from)>\(to)") ? to : from
            let tail = head == from ? to : from
            guard head != tail, seen.insert("\(head)>\(tail)").inserted else { continue }
            forward.append((head, tail))
        }
        return forward
    }

    private static func layered(_ count: Int, _ arcs: [(Int, Int)]) -> Model {
        let rank = ranks(count, arcs)
        let depth = (rank.max() ?? 0) + 1
        var rows = Array(repeating: [Int](), count: depth)
        for node in 0..<count {
            rows[rank[node]].append(node)
        }
        var neighbors: [Int: [Int]] = [:]
        var nextID = count
        for (from, to) in arcs {
            let span = rank[to] - rank[from]
            guard span > 0 else { continue }
            var cursor = from
            if span > 1 {
                for level in (rank[from] + 1)..<rank[to] {
                    let dummy = nextID
                    nextID += 1
                    rows[level].append(dummy)
                    connect(&neighbors, cursor, dummy)
                    cursor = dummy
                }
            }
            connect(&neighbors, cursor, to)
        }
        return Model(rows: rows, neighbors: neighbors)
    }

    private static func ranks(_ count: Int, _ arcs: [(Int, Int)]) -> [Int] {
        var outgoing = Array(repeating: [Int](), count: count)
        var pending = Array(repeating: 0, count: count)
        for (from, to) in arcs {
            outgoing[from].append(to)
            pending[to] += 1
        }
        var rank = Array(repeating: 0, count: count)
        var queue = (0..<count).filter { pending[$0] == 0 }
        var head = 0
        while head < queue.count {
            let node = queue[head]
            head += 1
            for next in outgoing[node] {
                rank[next] = max(rank[next], rank[node] + 1)
                pending[next] -= 1
                if pending[next] == 0 {
                    queue.append(next)
                }
            }
        }
        return rank
    }

    private static func connect(_ neighbors: inout [Int: [Int]], _ left: Int, _ right: Int) {
        if neighbors[left]?.contains(right) != true {
            neighbors[left, default: []].append(right)
        }
        if neighbors[right]?.contains(left) != true {
            neighbors[right, default: []].append(left)
        }
    }

    struct Model {
        var rows: [[Int]]
        var neighbors: [Int: [Int]]
    }
}
