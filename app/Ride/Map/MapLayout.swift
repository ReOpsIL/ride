import CoreGraphics
import Foundation

extension MapGraph {
    func laidOut() -> MapGraph {
        var copy = self
        copy.nodes = copy.nodes.map { node in
            var node = node
            node.nested = node.nested?.laidOut()
            return node
        }
        return MapArrange.kamadaKawai.apply(copy)
    }
}
