import Foundation

enum MapTree {
    static func graph(_ dir: URL) -> MapGraph {
        var nodes: [MapNode] = []
        for child in MapIO.children(dir) where !MapIO.skip(child) {
            if MapIO.isDirectory(child) {
                if MapCargo.package(at: child) != nil || MapIO.containsSource(child) {
                    nodes.append(node(child))
                }
            } else if MapIO.isSource(child) {
                nodes.append(fileNode(child))
            }
        }
        return MapGraph(title: dir.lastPathComponent, nodes: nodes, edges: [])
    }

    static func node(_ dir: URL) -> MapNode {
        if let package = MapCargo.package(at: dir) {
            return MapRust.projectNode(package)
        }
        let nested = graph(dir)
        return MapNode(
            id: dir.standardizedFileURL.path,
            title: dir.lastPathComponent,
            detail: "folder",
            kind: .module,
            path: nil,
            nested: nested.nodes.isEmpty ? nil : nested
        )
    }

    static func fileNode(_ file: URL) -> MapNode {
        MapNode(
            id: file.standardizedFileURL.path,
            title: file.lastPathComponent,
            detail: file.pathExtension.lowercased(),
            kind: .file,
            path: file.path,
            nested: symbols(file)
        )
    }

    static func symbols(_ file: URL) -> MapGraph? {
        let ext = file.pathExtension.lowercased()
        if ext == "rs" {
            let graph = MapRust.moduleGraph(file: file, visited: [])
            return graph.nodes.isEmpty ? nil : graph
        }
        if ext == "swift" {
            return symbolGraph(
                MapIO.read(file),
                file: file,
                keywords: MapSource.swiftKeywords,
                prefixes: MapSource.swiftPrefixes,
                procedures: false
            )
        }
        if cExt.contains(ext) {
            return symbolGraph(
                MapIO.read(file),
                file: file,
                keywords: MapSource.cKeywords,
                prefixes: MapSource.cPrefixes,
                procedures: true
            )
        }
        return nil
    }

    private static let cExt: Set<String> = ["c", "h", "hh", "hpp", "hxx", "cpp", "cc", "cxx", "m", "mm"]

    private static func symbolGraph(
        _ text: String,
        file: URL,
        keywords: Set<String>,
        prefixes: Set<String>,
        procedures: Bool
    ) -> MapGraph? {
        let parsed = MapSource.parse(text, keywords: keywords, prefixes: prefixes)
        var nodes: [MapNode] = []
        for (index, decl) in parsed.decls.enumerated() {
            var nested: MapGraph?
            if let inline = decl.inline, MapSource.nesting.contains(decl.keyword) {
                nested = symbolGraph(inline, file: file, keywords: keywords, prefixes: prefixes, procedures: procedures)
            }
            nodes.append(MapNode(
                id: "\(file.standardizedFileURL.path)#\(decl.keyword)#\(decl.name)#\(index)",
                title: decl.name,
                detail: decl.keyword,
                kind: kind(decl.keyword),
                path: file.path,
                nested: nested?.nodes.isEmpty == false ? nested : nil
            ))
        }
        if procedures {
            let have = Set(nodes.map(\.title))
            for (index, name) in MapProcs.names(text).enumerated() where !have.contains(name) {
                nodes.append(MapNode(
                    id: "\(file.standardizedFileURL.path)#fn#\(name)#\(index)",
                    title: name,
                    detail: "function",
                    kind: .function,
                    path: file.path,
                    nested: nil
                ))
            }
        }
        return nodes.isEmpty ? nil : MapGraph(title: file.lastPathComponent, nodes: nodes, edges: [])
    }

    private static func kind(_ keyword: String) -> MapKind {
        switch keyword {
        case "func", "fn": .function
        default: .type
        }
    }
}
