import CoreGraphics
import Foundation

enum MapStress {
    static func apply(_ graph: MapGraph) -> MapGraph {
        MapSpread.finish(graph, positions)
    }

    static func positions(_ graph: MapGraph) -> [CGPoint] {
        let count = graph.nodes.count
        guard count > 1 else { return MapSpread.seeds(graph) }
        let dist = hops(graph)
        var maxHop = 1
        for row in dist {
            for hop in row where hop > maxHop { maxHop = hop }
        }
        var points = MapSpread.seeds(graph)
        let length = Double(MapSpread.length)
        for _ in 0..<140 {
            var next = points
            for i in 0..<count {
                var numX = 0.0
                var numY = 0.0
                var den = 0.0
                for j in 0..<count where i != j {
                    let hop = dist[i][j] > 0 ? dist[i][j] : maxHop + 1
                    let ideal = Double(hop) * length
                    let weight = 1.0 / Double(hop * hop)
                    let diffX = Double(points[i].x - points[j].x)
                    let diffY = Double(points[i].y - points[j].y)
                    let mag = max(hypot(diffX, diffY), 0.01)
                    den += weight
                    numX += weight * (Double(points[j].x) + ideal * diffX / mag)
                    numY += weight * (Double(points[j].y) + ideal * diffY / mag)
                }
                guard den > 0 else { continue }
                let aimX = numX / den
                let aimY = numY / den
                next[i].x = CGFloat(Double(points[i].x) * 0.45 + aimX * 0.55)
                next[i].y = CGFloat(Double(points[i].y) * 0.45 + aimY * 0.55)
            }
            points = next
        }
        return points
    }

    private static func hops(_ graph: MapGraph) -> [[Int]] {
        let count = graph.nodes.count
        let index = MapSpread.index(graph)
        var adjacent = Array(repeating: [Int](), count: count)
        for edge in graph.edges {
            guard let from = index[edge.from], let to = index[edge.to], from != to else { continue }
            adjacent[from].append(to)
            adjacent[to].append(from)
        }
        var dist = Array(repeating: Array(repeating: -1, count: count), count: count)
        for start in 0..<count {
            dist[start][start] = 0
            var queue = [start]
            var head = 0
            while head < queue.count {
                let node = queue[head]
                head += 1
                for next in adjacent[node] where dist[start][next] < 0 {
                    dist[start][next] = dist[start][node] + 1
                    queue.append(next)
                }
            }
        }
        return dist
    }
}
