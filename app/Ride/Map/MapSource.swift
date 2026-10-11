import Foundation

struct MapDecl: Equatable {
    var keyword: String
    var name: String
    var inline: String?
}

enum MapSource {
    static let rustKeywords: Set<String> = ["mod", "fn", "struct", "enum", "trait", "type", "const", "static", "impl"]
    static let rustPrefixes: Set<String> = ["pub", "async", "unsafe", "extern", "const"]
    static let swiftKeywords: Set<String> = ["func", "struct", "class", "enum", "protocol", "actor", "extension"]
    static let swiftPrefixes: Set<String> = [
        "public", "private", "internal", "fileprivate", "open", "final", "override",
        "static", "class", "mutating", "async", "nonisolated",
    ]
    static let cKeywords: Set<String> = ["struct", "enum", "union", "class", "namespace"]
    static let cPrefixes: Set<String> = [
        "typedef", "static", "inline", "extern", "const", "volatile", "virtual",
        "public", "private", "protected",
    ]
    static let nesting: Set<String> = [
        "mod", "impl", "trait", "extension", "class", "struct", "enum", "namespace", "protocol", "actor", "union",
    ]

    static func parse(
        _ text: String,
        keywords: Set<String>,
        prefixes: Set<String>
    ) -> (decls: [MapDecl], uses: [String]) {
        var parser = MapParser(text: text, keywords: keywords, prefixes: prefixes)
        parser.run()
        return (parser.decls, parser.uses)
    }
}

struct MapParser {
    var cursor: MapCursor
    let keywords: Set<String>
    let prefixes: Set<String>
    var decls: [MapDecl] = []
    var uses: [String] = []
    var paren = 0
    var bracket = 0

    init(text: String, keywords: Set<String>, prefixes: Set<String>) {
        cursor = MapCursor(text)
        self.keywords = keywords
        self.prefixes = prefixes
    }

    mutating func run() {
        var guardIndex = cursor.index
        var spins = 0
        while !cursor.done {
            step()
            if cursor.index == guardIndex {
                cursor.bump()
                spins += 1
                if spins > cursor.text.count { return }
            } else {
                spins = 0
                guardIndex = cursor.index
            }
        }
    }

    mutating func step() {
        cursor.skipTrivia()
        if cursor.done { return }
        if cursor.char == "#" {
            skipAttribute()
            return
        }
        if cursor.skipLiteral() { return }
        if cursor.char == "{" {
            _ = cursor.captureBody()
            return
        }
        if cursor.char == "(" {
            paren += 1
            cursor.bump()
            return
        }
        if cursor.char == ")" {
            paren = max(0, paren - 1)
            cursor.bump()
            return
        }
        if cursor.char == "[" {
            bracket += 1
            cursor.bump()
            return
        }
        if cursor.char == "]" {
            bracket = max(0, bracket - 1)
            cursor.bump()
            return
        }
        guard paren == 0, bracket == 0, let word = cursor.word() else {
            if let char = cursor.char, !(char.isLetter || char == "_") { cursor.bump() }
            return
        }
        if word == "pub", cursor.char == "(" {
            skipParens()
            return
        }
        if prefixes.contains(word), treatAsPrefix(word) { return }
        if keywords.contains(word) {
            takeDecl(word)
            return
        }
        if word == "use" {
            uses.append(contentsOf: MapUses.heads(cursor.untilSemicolon()))
        }
    }

    mutating func treatAsPrefix(_ word: String) -> Bool {
        if !keywords.contains(word) { return true }
        guard let next = cursor.peekWord() else { return false }
        return prefixes.contains(next) || keywords.contains(next) || next == "use"
    }

    mutating func takeDecl(_ keyword: String) {
        let raw = keyword == "impl" || keyword == "extension" ? cursor.header() : (cursor.word() ?? keyword)
        let name = MapNames.clean(raw)
        decls.append(MapDecl(
            keyword: keyword,
            name: name.isEmpty ? keyword : name,
            inline: cursor.followingBody()
        ))
    }

    mutating func skipAttribute() {
        cursor.bump()
        cursor.skipTrivia()
        if cursor.char == "!" { cursor.bump() }
        guard cursor.char == "[" else { return }
        var depth = 0
        repeat {
            if cursor.char == "[" { depth += 1 }
            if cursor.char == "]" { depth -= 1 }
            cursor.bump()
        } while !cursor.done && depth > 0
    }

    mutating func skipParens() {
        var depth = 0
        repeat {
            if cursor.char == "(" { depth += 1 }
            if cursor.char == ")" { depth -= 1 }
            cursor.bump()
        } while !cursor.done && depth > 0
    }
}

enum MapUses {
    static func heads(_ text: String) -> [String] {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("::") { body.removeFirst(2) }
        for prefix in ["crate::", "super::", "self::"] where body.hasPrefix(prefix) {
            body.removeFirst(prefix.count)
        }
        if let brace = body.firstIndex(of: "{") { body = String(body[..<brace]) }
        if let alias = body.range(of: " as ") { body = String(body[..<alias.lowerBound]) }
        let segment = body.split(separator: ":").map {
            $0.trimmingCharacters(in: .whitespaces)
        }.first { !$0.isEmpty }
        guard let segment, !segment.isEmpty else { return [] }
        return [String(segment)]
    }
}

enum MapProcs {
    static let controls: Set<String> = ["if", "for", "while", "switch", "catch", "return"]

    static func names(_ text: String) -> [String] {
        var depth = 0
        var found: [String] = []
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = strip(String(raw))
            if depth == 0, let name = procedure(line), !controls.contains(name), !found.contains(name) {
                found.append(name)
            }
            depth += line.filter { $0 == "{" }.count
            depth -= line.filter { $0 == "}" }.count
            if depth < 0 { depth = 0 }
        }
        return found
    }

    private static func strip(_ line: String) -> String {
        guard let range = line.range(of: "//") else { return line }
        return String(line[..<range.lowerBound])
    }

    private static func procedure(_ line: String) -> String? {
        guard let paren = line.firstIndex(of: "(") else { return nil }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasSuffix(";"), line[paren...].contains(")") else { return nil }
        let token = line[..<paren].split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "_") }).last
        guard let token, token.first?.isNumber != true else { return nil }
        return String(token)
    }
}
