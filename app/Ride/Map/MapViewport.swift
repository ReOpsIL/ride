import CoreGraphics
import Foundation

struct MapViewport: Equatable {
    var zoom: CGFloat = 1
    var pan: CGSize = .zero

    mutating func zoom(by factor: CGFloat, at pivot: CGPoint) {
        guard factor.isFinite, factor > 0 else { return }
        zoom(to: zoom * factor, at: pivot)
    }

    mutating func zoom(to requested: CGFloat, at pivot: CGPoint) {
        let next = MapZoom.clamp(requested, MapMetrics.minZoom, MapMetrics.maxZoom)
        guard next != zoom, zoom > 0 else { return }
        let ratio = next / zoom
        pan = CGSize(
            width: pivot.x - (pivot.x - pan.width) * ratio,
            height: pivot.y - (pivot.y - pan.height) * ratio
        )
        zoom = next
    }

    mutating func fit(content: CGSize, in viewport: CGSize) {
        guard content.width > 0, content.height > 0, viewport.width > 0, viewport.height > 0 else { return }
        let scale = min(viewport.width / content.width, viewport.height / content.height) * 0.9
        zoom = MapZoom.clamp(min(1, scale), MapMetrics.minZoom, MapMetrics.maxZoom)
        pan = CGSize(
            width: max(24, (viewport.width - content.width * zoom) / 2),
            height: max(24, (viewport.height - content.height * zoom) / 2)
        )
    }

    mutating func reset() {
        zoom = 1
        pan = .zero
    }

    func flowPoint(at screen: CGPoint) -> CGPoint {
        CGPoint(x: (screen.x - pan.width) / zoom, y: (screen.y - pan.height) / zoom)
    }

    func screenPoint(at flow: CGPoint) -> CGPoint {
        CGPoint(x: flow.x * zoom + pan.width, y: flow.y * zoom + pan.height)
    }
}

enum MapZoom {
    static func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
        min(max(value, low), high)
    }

    static func scrollFactor(_ delta: CGFloat) -> CGFloat {
        exp(clamp(delta, -8, 8) * 0.035)
    }

    static func magnifyFactor(_ delta: CGFloat) -> CGFloat {
        exp(clamp(delta, -1, 1) * 0.5)
    }
}
