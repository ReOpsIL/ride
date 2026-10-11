import SwiftUI

struct MapEdges: View {
    let graph: MapGraph
    let viewport: MapViewport

    var body: some View {
        Canvas { context, _ in
            for edge in graph.edges {
                guard let flowSource = graph.anchor(of: edge.from, toward: edge.to),
                      let flowTarget = graph.anchor(of: edge.to, toward: edge.from)
                else { continue }
                let source = viewport.screenPoint(at: flowSource)
                let target = viewport.screenPoint(at: flowTarget)
                let color = edge.kind == .depends ? Color.blue.opacity(0.9) : Color.mint.opacity(0.85)
                let width = (edge.kind == .depends ? 2.2 : 1.5) * viewport.zoom
                let drawn = curve(from: source, to: target)
                context.stroke(
                    drawn.path,
                    with: .color(color),
                    style: StrokeStyle(
                        lineWidth: width,
                        lineCap: .round,
                        dash: edge.kind == .uses ? [6 * viewport.zoom, 4 * viewport.zoom] : []
                    )
                )
                arrow(context: context, tip: target, from: drawn.approach, color: color)
            }
        }
        .allowsHitTesting(false)
    }

    private func curve(from source: CGPoint, to target: CGPoint) -> (path: Path, approach: CGPoint) {
        let dx = target.x - source.x
        let dy = target.y - source.y
        let across = abs(dx) >= abs(dy)
        let span = across ? abs(dx) : abs(dy)
        let bend = max(16, span * 0.42)
        let control1: CGPoint
        let control2: CGPoint
        if across {
            let sign: CGFloat = dx >= 0 ? 1 : -1
            control1 = CGPoint(x: source.x + sign * bend, y: source.y)
            control2 = CGPoint(x: target.x - sign * bend, y: target.y)
        } else {
            let sign: CGFloat = dy >= 0 ? 1 : -1
            control1 = CGPoint(x: source.x, y: source.y + sign * bend)
            control2 = CGPoint(x: target.x, y: target.y - sign * bend)
        }
        var path = Path()
        path.move(to: source)
        path.addCurve(to: target, control1: control1, control2: control2)
        return (path, control2)
    }

    private func arrow(context: GraphicsContext, tip: CGPoint, from source: CGPoint, color: Color) {
        let angle = atan2(tip.y - source.y, tip.x - source.x)
        let size = 8 * viewport.zoom
        var path = Path()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - size * cos(angle - 0.45), y: tip.y - size * sin(angle - 0.45)))
        path.addLine(to: CGPoint(x: tip.x - size * cos(angle + 0.45), y: tip.y - size * sin(angle + 0.45)))
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }
}
