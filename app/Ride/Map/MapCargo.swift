import Foundation

struct MapPackage: Equatable {
    var name: String
    var root: URL
}

enum MapCargo {
    static func packages(in root: URL) -> [MapPackage] {
        let text = MapIO.read(root.appendingPathComponent("Cargo.toml"))
        guard !text.isEmpty else { return [] }
        let members = memberPaths(text)
        if !members.isEmpty {
            return members.flatMap { resolve($0, workspace: root) }
        }
        guard let package = package(at: root) else { return [] }
        return [package]
    }

    static func package(at root: URL) -> MapPackage? {
        let text = MapIO.read(root.appendingPathComponent("Cargo.toml"))
        guard let name = packageName(text) else { return nil }
        return MapPackage(name: name, root: root.standardizedFileURL)
    }

    static func edges(_ packages: [MapPackage]) -> [MapEdge] {
        let roots = Set(packages.map { $0.root.standardizedFileURL.path })
        var edges: [MapEdge] = []
        var seen: Set<String> = []
        for package in packages {
            let text = MapIO.read(package.root.appendingPathComponent("Cargo.toml"))
            let from = package.root.standardizedFileURL.path
            for relative in dependencyPaths(text) {
                let dest = package.root.appendingPathComponent(relative).standardizedFileURL.path
                guard roots.contains(dest), dest != from else { continue }
                let edge = MapEdge(from: from, to: dest, kind: .depends)
                if seen.insert(edge.id).inserted { edges.append(edge) }
            }
        }
        return edges
    }

    static func binPaths(_ text: String) -> [String] {
        var paths: [String] = []
        var inBin = false
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inBin = line == "[[bin]]"
                continue
            }
            guard inBin, let value = stringValue(String(line), key: "path") else { continue }
            paths.append(value)
        }
        return paths
    }

    static func memberPaths(_ text: String) -> [String] {
        guard let body = section(text, named: "workspace"), let key = body.range(of: "members") else { return [] }
        let tail = body[key.upperBound...]
        guard let open = tail.firstIndex(of: "[") else { return [] }
        var values: [String] = []
        var current = ""
        var inString = false
        var escaped = false
        for char in tail[tail.index(after: open)...] {
            if inString {
                if escaped {
                    current.append(char)
                    escaped = false
                    continue
                }
                if char == "\\" {
                    escaped = true
                    continue
                }
                if char == "\"" {
                    inString = false
                    values.append(current)
                    current = ""
                    continue
                }
                current.append(char)
                continue
            }
            if char == "\"" {
                inString = true
                continue
            }
            if char == "]" { break }
        }
        return values
    }

    static func dependencyPaths(_ text: String) -> [String] {
        var active = false
        var paths: [String] = []
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                active = trimmed.dropFirst().dropLast().lowercased().contains("dependencies")
                continue
            }
            guard active, let range = trimmed.range(of: "path") else { continue }
            guard let value = quoted(afterEquals: String(trimmed[range.upperBound...])) else { continue }
            paths.append(value)
        }
        return paths
    }

    private static func resolve(_ member: String, workspace: URL) -> [MapPackage] {
        if member.contains("*") {
            let dir = workspace.appendingPathComponent(member.replacingOccurrences(of: "*", with: ""))
            return MapIO.children(dir).compactMap { child in
                MapIO.isDirectory(child) ? package(at: child) : nil
            }
        }
        return package(at: workspace.appendingPathComponent(member)).map { [$0] } ?? []
    }

    private static func packageName(_ text: String) -> String? {
        guard let body = section(text, named: "package") else { return nil }
        for raw in body.split(separator: "\n") {
            if let value = stringValue(String(raw), key: "name") { return value }
        }
        return nil
    }

    private static func section(_ text: String, named name: String) -> String? {
        var collecting = false
        var lines: [String] = []
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("["), trimmed.hasSuffix("]"), !trimmed.hasPrefix("[[") {
                let header = trimmed.dropFirst().dropLast()
                if collecting {
                    if header == name || header.hasPrefix(name + ".") {
                        lines.append(line)
                        continue
                    }
                    break
                }
                collecting = header == name
                if collecting { lines.append(line) }
                continue
            }
            if collecting { lines.append(line) }
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private static func stringValue(_ line: String, key: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(key) else { return nil }
        let rest = trimmed.dropFirst(key.count).trimmingCharacters(in: .whitespaces)
        guard rest.hasPrefix("=") else { return nil }
        return quoted(afterEquals: String(rest))
    }

    private static func quoted(afterEquals text: String) -> String? {
        guard let eq = text.firstIndex(of: "=") else {
            return text.hasPrefix("\"") ? quotedBody(text) : nil
        }
        let tail = text[text.index(after: eq)...].trimmingCharacters(in: .whitespaces)
        return quotedBody(tail)
    }

    private static func quotedBody(_ text: String) -> String? {
        guard text.hasPrefix("\"") else { return nil }
        var out = ""
        var escaped = false
        for char in text.dropFirst() {
            if escaped {
                out.append(char)
                escaped = false
                continue
            }
            if char == "\\" {
                escaped = true
                continue
            }
            if char == "\"" { return out }
            out.append(char)
        }
        return nil
    }
}
