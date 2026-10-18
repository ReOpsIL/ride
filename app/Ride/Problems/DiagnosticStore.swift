import Foundation

enum ProblemLevel: Equatable, Hashable {
    case error
    case warning
}

enum DiagnosticOrigin: Equatable, Hashable {
    case check
    case build
    case live
}

struct StoredEdit: Equatable, Hashable {
    var startByte: UInt32
    var endByte: UInt32
    var text: String
    var caretByte: UInt32
}

struct StoredFix: Equatable, Hashable {
    var title: String
    var edits: [StoredEdit]
}

struct StoredDiagnostic: Equatable, Hashable {
    var primary: StoredLabel
    var level: ProblemLevel
    var message: String
    var code: String?
    var fixes: [StoredFix] = []
    var origin: DiagnosticOrigin = .check
    var secondary: [StoredLabel] = []
    var notes: [StoredNote] = []

    var path: String { primary.path }
    var byteStart: UInt32 { primary.byteStart }
    var byteEnd: UInt32 { primary.byteEnd }
    var line: UInt32 { primary.lineStart }
    var column: UInt32 { primary.column }
}

extension StoredDiagnostic {
    init(
        path: String,
        byteStart: UInt32,
        byteEnd: UInt32,
        line: UInt32,
        column: UInt32,
        level: ProblemLevel,
        message: String,
        code: String?,
        fixes: [StoredFix] = [],
        origin: DiagnosticOrigin = .check,
        secondary: [StoredLabel] = [],
        notes: [StoredNote] = []
    ) {
        self.init(
            primary: StoredLabel(
                path: path,
                byteStart: byteStart,
                byteEnd: byteEnd,
                lineStart: line,
                lineEnd: line,
                column: column,
                text: nil,
                macroName: nil
            ),
            level: level,
            message: message,
            code: code,
            fixes: fixes,
            origin: origin,
            secondary: secondary,
            notes: notes
        )
    }
}

struct DiagnosticStore {
    private var clang: [String: [StoredDiagnostic]] = [:]
    private var cargo: [String: [StoredDiagnostic]] = [:]
    private var build: [StoredDiagnostic] = []
    private var owner: [String: String] = [:]
    private var liveClang: [String: [StoredDiagnostic]] = [:]
    private var tidy: [String: [StoredDiagnostic]] = [:]

    mutating func insert(_ item: StoredDiagnostic) {
        clang[item.path, default: []].append(item)
        if owner[item.path] == nil {
            owner[item.path] = item.path
        }
    }

    mutating func replace(path: String, with items: [StoredDiagnostic]) {
        let mine = items.filter { $0.path == path }
        if mine.isEmpty {
            clang.removeValue(forKey: path)
            owner.removeValue(forKey: path)
        } else {
            clang[path] = mine
            if owner[path] == nil {
                owner[path] = path
            }
        }
    }

    mutating func replace(from source: String, with items: [StoredDiagnostic]) {
        for path in owner.compactMap({ $0.value == source ? $0.key : nil }) {
            clang.removeValue(forKey: path)
            owner.removeValue(forKey: path)
        }
        for (path, group) in Dictionary(grouping: items, by: \.path) {
            clang[path] = group
            owner[path] = source
        }
    }

    @discardableResult
    mutating func remove(path: String) -> Bool {
        owner.removeValue(forKey: path)
        let hadLive = liveClang.removeValue(forKey: path) != nil
        let hadTidy = tidy.removeValue(forKey: path) != nil
        return (clang.removeValue(forKey: path) != nil) || hadLive || hadTidy
    }

    mutating func replaceLive(path: String, with items: [StoredDiagnostic]) {
        let mine = items.filter { $0.path == path }.map(Self.asLive)
        if mine.isEmpty {
            liveClang.removeValue(forKey: path)
        } else {
            liveClang[path] = mine
        }
    }

    mutating func replaceTidy(path: String, with items: [StoredDiagnostic]) {
        let lint = items.filter { $0.path == path && Self.isLint($0) }
        tidy[path] = lint.isEmpty ? nil : lint
    }

    private static func isLint(_ item: StoredDiagnostic) -> Bool {
        guard let code = item.code else {
            return false
        }
        return !code.hasPrefix("clang-diagnostic")
    }

    mutating func replaceLiveCargo(root: String, _ items: [StoredDiagnostic]) {
        cargo[root] = items.map(Self.asLive)
    }

    private static func asLive(_ item: StoredDiagnostic) -> StoredDiagnostic {
        var next = item
        next.origin = .live
        return next
    }

    mutating func replaceCargo(root: String, _ items: [StoredDiagnostic]) {
        cargo[root] = items
    }

    mutating func replaceBuild(_ items: [StoredDiagnostic]) {
        build = items.map {
            var item = $0
            item.origin = .build
            return item
        }
    }

    mutating func replaceAllClang(from source: String, with items: [StoredDiagnostic]) {
        clang.removeAll()
        owner.removeAll()
        replace(from: source, with: items)
    }

    var snapshot: [StoredDiagnostic] {
        let liveKeys = Set(liveClang.keys)
        let liveItems = liveClang.values.flatMap { $0 }
        let saveClang = clang.filter { !liveKeys.contains($0.key) }.values.flatMap { $0 }
        let lint = tidy.values.flatMap { $0 }
        return (liveItems + saveClang + lint + cargo.values.flatMap { $0 } + build).sorted {
            ($0.path, $0.byteStart) < ($1.path, $1.byteStart)
        }
    }

    var clangPaths: [String] {
        Array(Set(clang.keys).union(liveClang.keys).union(tidy.keys))
    }

    var buildDiagnostics: [StoredDiagnostic] {
        build
    }
}
