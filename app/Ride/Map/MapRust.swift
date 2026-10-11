import Foundation

enum MapRust {
    static func projectNode(_ package: MapPackage) -> MapNode {
        let nested = graph(package)
        return MapNode(
            id: package.root.standardizedFileURL.path,
            title: package.name,
            detail: "crate",
            kind: .project,
            path: package.root.appendingPathComponent("Cargo.toml").path,
            nested: nested.nodes.isEmpty ? nil : nested
        )
    }

    static func graph(_ package: MapPackage) -> MapGraph {
        let roots = entryFiles(package)
        if roots.count == 1, let file = roots.first {
            var graph = moduleGraph(file: file, visited: [])
            graph.title = package.name
            return graph
        }
        let nodes = roots.map { file in
            let nested = moduleGraph(file: file, visited: [])
            return MapNode(
                id: file.standardizedFileURL.path,
                title: file.deletingPathExtension().lastPathComponent,
                detail: "root",
                kind: .file,
                path: file.path,
                nested: nested.nodes.isEmpty ? nil : nested
            )
        }
        return MapGraph(title: package.name, nodes: nodes, edges: [])
    }

    static func moduleGraph(file: URL, visited: Set<String>) -> MapGraph {
        parsed(file: file, visited: visited).0
    }

    static func items(text: String, file: URL, title: String, visited: Set<String>) -> MapGraph {
        built(text: text, file: file, title: title, visited: visited).0
    }

    private static func parsed(file: URL, visited: Set<String>) -> (MapGraph, [String]) {
        let path = file.standardizedFileURL.path
        let title = file.deletingPathExtension().lastPathComponent
        if visited.contains(path) { return (MapGraph(title: title, nodes: [], edges: []), []) }
        var visited = visited
        visited.insert(path)
        return built(text: MapIO.read(file), file: file, title: title, visited: visited)
    }

    private static func built(
        text: String,
        file: URL,
        title: String,
        visited: Set<String>
    ) -> (MapGraph, [String]) {
        let parsed = MapSource.parse(text, keywords: MapSource.rustKeywords, prefixes: MapSource.rustPrefixes)
        let rows = parsed.decls.enumerated().map { node($1, index: $0, file: file, visited: visited) }
        let modules = rows.map(\.0).filter { $0.kind == .module }
        var edges: [MapEdge] = []
        var seen: Set<String> = []
        for (node, uses) in rows where node.kind == .module {
            for head in uses {
                for target in modules where target.title == head && target.id != node.id {
                    let edge = MapEdge(from: node.id, to: target.id, kind: .uses)
                    if seen.insert(edge.id).inserted { edges.append(edge) }
                }
            }
        }
        return (MapGraph(title: title, nodes: rows.map(\.0), edges: edges), parsed.uses)
    }

    private static func node(
        _ decl: MapDecl,
        index: Int,
        file: URL,
        visited: Set<String>
    ) -> (MapNode, [String]) {
        var id = "\(file.standardizedFileURL.path)#\(decl.keyword)#\(decl.name)#\(index)"
        var path: String? = decl.keyword == "mod" ? nil : file.path
        var nested: MapGraph?
        var uses: [String] = []
        if decl.keyword == "mod", decl.inline == nil, let child = moduleFile(named: decl.name, parent: file) {
            id = child.standardizedFileURL.path
            path = child.path
            let parsed = parsed(file: child, visited: visited)
            nested = parsed.0.nodes.isEmpty ? nil : parsed.0
            uses = parsed.1
        } else if let inline = decl.inline, MapSource.nesting.contains(decl.keyword) {
            let parsed = built(text: inline, file: file, title: decl.name, visited: visited)
            nested = parsed.0.nodes.isEmpty ? nil : parsed.0
            if decl.keyword == "mod" { uses = parsed.1 }
        }
        return (MapNode(
            id: id,
            title: decl.name,
            detail: decl.keyword,
            kind: kind(decl.keyword),
            path: path,
            nested: nested
        ), uses)
    }

    private static func kind(_ keyword: String) -> MapKind {
        switch keyword {
        case "mod": .module
        case "fn": .function
        case "const", "static": .value
        default: .type
        }
    }

    private static func moduleFile(named name: String, parent: URL) -> URL? {
        let fileName = parent.lastPathComponent
        let base: URL
        if fileName == "mod.rs" || fileName == "lib.rs" || fileName == "main.rs" {
            base = parent.deletingLastPathComponent()
        } else {
            base = parent.deletingLastPathComponent()
                .appendingPathComponent(parent.deletingPathExtension().lastPathComponent)
        }
        let file = base.appendingPathComponent("\(name).rs")
        if MapIO.isFile(file) { return file }
        let mod = base.appendingPathComponent(name).appendingPathComponent("mod.rs")
        return MapIO.isFile(mod) ? mod : nil
    }

    private static func entryFiles(_ package: MapPackage) -> [URL] {
        var files: [URL] = []
        let src = package.root.appendingPathComponent("src")
        for name in ["lib.rs", "main.rs"] {
            let url = src.appendingPathComponent(name)
            if MapIO.isFile(url) { files.append(url) }
        }
        let cargo = MapIO.read(package.root.appendingPathComponent("Cargo.toml"))
        for relative in MapCargo.binPaths(cargo) {
            let url = package.root.appendingPathComponent(relative).standardizedFileURL
            if MapIO.isFile(url) { files.append(url) }
        }
        for child in MapIO.children(src.appendingPathComponent("bin")) where !MapIO.skip(child) {
            if MapIO.isFile(child), child.pathExtension == "rs" {
                files.append(child)
            } else if MapIO.isDirectory(child) {
                let main = child.appendingPathComponent("main.rs")
                if MapIO.isFile(main) { files.append(main) }
            }
        }
        var seen: Set<String> = []
        return files.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }
}
