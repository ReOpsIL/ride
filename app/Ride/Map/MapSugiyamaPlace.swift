import CoreGraphics
import Foundation

extension MapSugiyama {
    static func sweep(_ model: Model) -> Model {
        var rows = model.rows
        guard rows.count > 1 else { return model }
        for pass in 0..<8 {
            let downward = pass % 2 == 0
            let levels = downward ? Array(1..<rows.count) : Array((0..<(rows.count - 1)).reversed())
            for level in levels {
                let anchor = rows[level + (downward ? -1 : 1)]
                let slot = Dictionary(uniqueKeysWithValues: anchor.enumerated().map { ($1, $0) })
                let indexed = rows[level].enumerated().sorted { lhs, rhs in
                    let left = bary(lhs.element, model.neighbors, slot, lhs.offset)
                    let right = bary(rhs.element, model.neighbors, slot, rhs.offset)
                    if left != right { return left < right }
                    return lhs.offset < rhs.offset
                }
                rows[level] = indexed.map(\.element)
            }
        }
        return Model(rows: rows, neighbors: model.neighbors)
    }

    static func coordinates(_ count: Int, _ rows: [[Int]], _ neighbors: [Int: [Int]]) -> [CGPoint] {
        let xGap = MapSpread.box.width
        let yGap = MapSpread.box.height
        var x: [Int: CGFloat] = [:]
        for row in rows {
            for (index, node) in row.enumerated() {
                x[node] = CGFloat(index) * xGap
            }
        }
        for _ in 0..<4 {
            pull(&x, rows, neighbors, downward: true, gap: xGap)
            pull(&x, rows, neighbors, downward: false, gap: xGap)
        }
        var points = Array(repeating: CGPoint.zero, count: count)
        for (level, row) in rows.enumerated() {
            for node in row where node < count {
                points[node] = CGPoint(x: x[node] ?? 0, y: CGFloat(level) * yGap)
            }
        }
        return points
    }

    private static func bary(_ node: Int, _ neighbors: [Int: [Int]], _ slot: [Int: Int], _ home: Int) -> Double {
        let near = (neighbors[node] ?? []).compactMap { slot[$0] }
        guard !near.isEmpty else { return Double(home) }
        return Double(near.reduce(0, +)) / Double(near.count)
    }

    private static func pull(
        _ x: inout [Int: CGFloat],
        _ rows: [[Int]],
        _ neighbors: [Int: [Int]],
        downward: Bool,
        gap: CGFloat
    ) {
        let levels = downward ? Array(rows.indices.dropFirst()) : Array(rows.indices.dropLast().reversed())
        for level in levels {
            let anchor = Set(rows[level + (downward ? -1 : 1)])
            let row = rows[level]
            let desired = row.map { node -> CGFloat in
                median((neighbors[node] ?? []).compactMap { anchor.contains($0) ? x[$0] : nil }, fallback: x[node] ?? 0)
            }
            var placed: [CGFloat] = []
            for (index, aim) in desired.enumerated() {
                let floor = index == 0 ? aim : placed[index - 1] + gap
                placed.append(max(aim, floor))
            }
            let aimMid = desired.reduce(0, +) / CGFloat(max(desired.count, 1))
            let gotMid = placed.reduce(0, +) / CGFloat(max(placed.count, 1))
            let shift = aimMid - gotMid
            for (index, node) in row.enumerated() {
                x[node] = placed[index] + shift
            }
        }
    }

    private static func median(_ values: [CGFloat], fallback: CGFloat) -> CGFloat {
        let ordered = values.sorted()
        guard !ordered.isEmpty else { return fallback }
        let mid = ordered.count / 2
        if ordered.count % 2 == 1 { return ordered[mid] }
        return (ordered[mid - 1] + ordered[mid]) / 2
    }
}
