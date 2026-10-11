import AppKit
import SwiftUI

struct MapCanvas: View {
    @ObservedObject var session: MapSession
    let onPress: (MapNode) -> Void
    let onOpen: (MapNode) -> Void

    @State private var viewport = MapViewport()
    @State private var panStart: CGSize?
    @State private var panMoved = false
    @State private var cardMoved = false
    @State private var lastClick: (id: String, at: Date)?
    @State private var viewportSize: CGSize = .zero

    private var token: String {
        session.crumbs.joined(separator: "/")
            + "#\(session.graph.nodes.count)#\(session.layoutNonce)"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                MapGrid(viewport: viewport)
                    .background(Color.primary.opacity(0.03))
                    .contentShape(Rectangle())
                    .gesture(panGesture)
                    .onTapGesture {
                        if panMoved {
                            panMoved = false
                            return
                        }
                        session.clearSelection()
                    }
                MapEdges(graph: session.graph, viewport: viewport)
                ForEach(session.graph.nodes) { node in
                    card(node)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            .background(MapMonitor(enabled: true, onScroll: { delta, cursor in
                viewport.zoom(by: MapZoom.scrollFactor(delta), at: cursor)
            }, onMagnify: { delta, cursor in
                viewport.zoom(by: MapZoom.magnifyFactor(delta), at: cursor)
            }))
            .overlay(alignment: .topTrailing) {
                MapArrangeChrome(selected: session.arrangement) { session.arrange($0) }
            }
            .overlay(alignment: .bottomTrailing) {
                MapZoomChrome(
                    zoom: viewport.zoom,
                    onZoomOut: { viewport.zoom(by: 1 / 1.15, at: center) },
                    onZoomIn: { viewport.zoom(by: 1.15, at: center) },
                    onReset: { fit() }
                )
            }
            .overlay(alignment: .topLeading) {
                Text("Click a card to select it. Shift-click adds more. Drag the selection to move it. Double-click opens what is inside.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(8)
                    .allowsHitTesting(false)
            }
            .onAppear {
                viewportSize = geometry.size
                fit()
            }
            .onChange(of: geometry.size) { _, size in
                viewportSize = size
            }
            .onChange(of: token) { _, _ in
                viewport = MapViewport()
                fit()
            }
        }
    }

    private var center: CGPoint {
        CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
    }

    private func card(_ node: MapNode) -> some View {
        let zoom = viewport.zoom
        let origin = viewport.screenPoint(at: CGPoint(x: node.x, y: node.y))
        return MapCard(
            node: node,
            selected: session.selectedIDs.contains(node.id),
            scale: zoom,
            onOpen: { onOpen(node) },
            onEnter: { onPress(node) }
        )
        .frame(width: MapMetrics.nodeSize.width * zoom, height: MapMetrics.nodeSize.height * zoom)
        .contentShape(Rectangle())
        .offset(x: origin.x, y: origin.y)
        .onTapGesture {
            if cardMoved {
                cardMoved = false
                return
            }
            session.select(node.id, adding: shift)
            if !shift, secondClick(on: node.id) {
                onPress(node)
            }
        }
        .gesture(cardGesture(node, zoom: zoom))
    }

    private func cardGesture(_ node: MapNode, zoom: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !cardMoved {
                    cardMoved = true
                    session.beginDrag(node.id, adding: shift)
                }
                session.updateDrag(value.translation, zoom: zoom)
            }
            .onEnded { _ in
                session.endDrag()
                DispatchQueue.main.async { cardMoved = false }
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !panMoved {
                    panMoved = true
                    panStart = viewport.pan
                }
                let start = panStart ?? viewport.pan
                viewport.pan = CGSize(
                    width: start.width + value.translation.width,
                    height: start.height + value.translation.height
                )
            }
            .onEnded { _ in
                panStart = nil
                DispatchQueue.main.async { panMoved = false }
            }
    }

    private var shift: Bool {
        NSEvent.modifierFlags.contains(.shift)
    }

    private func secondClick(on id: String) -> Bool {
        let now = Date()
        if let lastClick, lastClick.id == id, now.timeIntervalSince(lastClick.at) < NSEvent.doubleClickInterval {
            self.lastClick = nil
            return true
        }
        lastClick = (id, now)
        return false
    }

    private func fit() {
        viewport.fit(content: session.graph.contentSize, in: viewportSize)
    }
}
