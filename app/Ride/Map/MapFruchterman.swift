import CoreGraphics
import Foundation

enum MapFruchterman {
    static func apply(_ graph: MapGraph) -> MapGraph {
        MapSpread.finish(graph, positions)
    }

    static func positions(_ graph: MapGraph) -> [CGPoint] {
        let count = graph.nodes.count
        guard count > 1 else { return MapSpread.seeds(graph) }
        var points = MapSpread.seeds(graph)
        let pairs = links(graph)
        let k = MapSpread.length
        let iterations = 90
        var temperature = k
        let cool = k / CGFloat(iterations)
        for _ in 0..<iterations {
            var dx = Array(repeating: CGFloat.zero, count: count)
            var dy = Array(repeating: CGFloat.zero, count: count)
            for i in 0..<count {
                for j in (i + 1)..<count {
                    var diffX = points[i].x - points[j].x
                    var diffY = points[i].y - points[j].y
                    var dist = hypot(diffX, diffY)
                    if dist < 0.01 {
                        diffX = 0.01
                        diffY = 0
                        dist = 0.01
                    }
                    let push = (k * k) / dist
                    let stepX = diffX / dist * push
                    let stepY = diffY / dist * push
                    dx[i] += stepX
                    dy[i] += stepY
                    dx[j] -= stepX
                    dy[j] -= stepY
                }
            }
            for (i, j) in pairs {
                let diffX = points[j].x - points[i].x
                let diffY = points[j].y - points[i].y
                let dist = max(hypot(diffX, diffY), 0.01)
                let pull = (dist * dist) / k
                let stepX = diffX / dist * pull
                let stepY = diffY / dist * pull
                dx[i] += stepX
                dy[i] += stepY
                dx[j] -= stepX
                dy[j] -= stepY
            }
            let cx = points.reduce(CGFloat.zero) { $0 + $1.x } / CGFloat(count)
            let cy = points.reduce(CGFloat.zero) { $0 + $1.y } / CGFloat(count)
            for i in 0..<count {
                dx[i] += (cx - points[i].x) * 0.04
                dy[i] += (cy - points[i].y) * 0.04
                let len = max(hypot(dx[i], dy[i]), 0.01)
                let step = min(len, temperature)
                points[i].x = clamp(points[i].x + dx[i] / len * step)
                points[i].y = clamp(points[i].y + dy[i] / len * step)
            }
            temperature = max(0.5, temperature - cool)
        }
        return points
    }

    private static func links(_ graph: MapGraph) -> [(Int, Int)] {
        let index = MapSpread.index(graph)
        var seen: Set<String> = []
        var pairs: [(Int, Int)] = []
        for edge in graph.edges {
            guard let from = index[edge.from], let to = index[edge.to], from != to else { continue }
            let low = min(from, to)
            let high = max(from, to)
            guard seen.insert("\(low)>\(high)").inserted else { continue }
            pairs.append((low, high))
        }
        return pairs
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, -80_000), 80_000)
    }
}
