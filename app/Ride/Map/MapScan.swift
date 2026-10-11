import Foundation

enum MapScan {
    static func graph(root: URL) -> MapGraph {
        let root = root.standardizedFileURL
        let packages = MapCargo.packages(in: root)
        var nodes = packages.map { MapRust.projectNode($0) }
        let edges = MapCargo.edges(packages)
        for child in MapIO.children(root) where !MapIO.skip(child) && MapIO.isDirectory(child) {
            if covered(child, packages: packages, workspace: root) { continue }
            guard MapCargo.package(at: child) != nil || MapIO.containsSource(child) else { continue }
            nodes.append(MapTree.node(child))
        }
        if packages.count == 1, nodes.count == 1, let nested = nodes[0].nested {
            var graph = nested
            graph.title = packages[0].name
            return graph.laidOut()
        }
        if nodes.isEmpty {
            return MapTree.graph(root).laidOut()
        }
        return MapGraph(title: root.lastPathComponent, nodes: nodes, edges: edges).laidOut()
    }

    private static func covered(_ child: URL, packages: [MapPackage], workspace: URL) -> Bool {
        let path = child.standardizedFileURL.path
        let workspacePath = workspace.standardizedFileURL.path
        for package in packages {
            let root = package.root.standardizedFileURL.path
            if root == workspacePath {
                if child.lastPathComponent == "src" { return true }
            } else if path == root || path.hasPrefix(root + "/") || root.hasPrefix(path + "/") {
                return true
            }
        }
        return false
    }
}
