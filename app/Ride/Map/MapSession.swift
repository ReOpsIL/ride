import Combine
import Foundation

final class MapSession: ObservableObject {
    @Published private(set) var stack: [MapGraph] = []
    @Published var selectedIDs: Set<String> = []
    @Published private(set) var arrangement: MapArrange?
    @Published private(set) var layoutNonce = 0
    @Published private(set) var loading = false
    private var rootURL: String?
    private var generation = 0
    private var dragOrigins: [String: CGPoint] = [:]
    private var arrangements: [MapArrange] = []

    var graph: MapGraph { stack.last ?? .empty }
    var crumbs: [String] { stack.map(\.title) }

    func reload(root: URL, force: Bool = false) {
        let path = root.standardizedFileURL.path
        if !force, rootURL == path, !stack.isEmpty { return }
        generation += 1
        let generation = generation
        rootURL = path
        loading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let graph = MapScan.graph(root: root)
            DispatchQueue.main.async {
                guard let self, self.generation == generation else { return }
                self.stack = [graph]
                self.selectedIDs = []
                self.note(.kamadaKawai, replacing: true)
                self.dragOrigins = [:]
                self.loading = false
            }
        }
    }

    func show(_ graph: MapGraph) {
        generation += 1
        rootURL = nil
        stack = [graph.laidOut()]
        selectedIDs = []
        note(.kamadaKawai, replacing: true)
        dragOrigins = [:]
        loading = false
    }

    func enter(_ id: String) {
        guard let nested = graph.node(id)?.nested, !nested.nodes.isEmpty else { return }
        stack.append(nested)
        selectedIDs = []
        note(.kamadaKawai, replacing: false)
        dragOrigins = [:]
    }

    func back(to index: Int) {
        guard stack.indices.contains(index), index < stack.count - 1 else { return }
        stack = Array(stack.prefix(index + 1))
        selectedIDs = []
        if arrangements.count > index + 1 {
            arrangements = Array(arrangements.prefix(index + 1))
        }
        arrangement = arrangements.last ?? .kamadaKawai
        dragOrigins = [:]
    }

    func arrange(_ kind: MapArrange) {
        guard var top = stack.last, top.nodes.count > 1 else { return }
        top = kind.apply(top)
        stack[stack.count - 1] = top
        note(kind, replacing: false)
        layoutNonce += 1
        dragOrigins = [:]
    }

    private func note(_ kind: MapArrange, replacing: Bool) {
        if replacing || arrangements.isEmpty {
            arrangements = [kind]
        } else if arrangements.count < stack.count {
            arrangements.append(kind)
        } else {
            arrangements[arrangements.count - 1] = kind
        }
        arrangement = kind
    }

    func select(_ id: String, adding: Bool) {
        if adding {
            if selectedIDs.contains(id) {
                selectedIDs.remove(id)
            } else {
                selectedIDs.insert(id)
            }
            return
        }
        selectedIDs = [id]
    }

    func clearSelection() {
        selectedIDs = []
    }

    func beginDrag(_ id: String, adding: Bool) {
        if adding {
            selectedIDs.insert(id)
        } else if !selectedIDs.contains(id) {
            selectedIDs = [id]
        }
        var origins: [String: CGPoint] = [:]
        for node in graph.nodes where selectedIDs.contains(node.id) {
            origins[node.id] = CGPoint(x: node.x, y: node.y)
        }
        dragOrigins = origins
    }

    func updateDrag(_ translation: CGSize, zoom: CGFloat) {
        guard !dragOrigins.isEmpty, var top = stack.last else { return }
        let scale = zoom > 0 ? zoom : 1
        let delta = CGSize(width: translation.width / scale, height: translation.height / scale)
        for index in top.nodes.indices {
            guard let origin = dragOrigins[top.nodes[index].id] else { continue }
            top.nodes[index].x = origin.x + delta.width
            top.nodes[index].y = origin.y + delta.height
        }
        stack[stack.count - 1] = top
    }

    func endDrag() {
        dragOrigins = [:]
    }
}
