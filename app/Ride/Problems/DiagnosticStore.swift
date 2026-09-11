import Foundation

enum ProblemLevel: Equatable, Hashable {
    case error
    case warning
}

enum DiagnosticOrigin: Equatable, Hashable {
    case check
    case build
}

struct StoredDiagnostic: Equatable, Hashable {
    var path: String
    var byteStart: UInt32
    var byteEnd: UInt32
    var line: UInt32
    var column: UInt32
    var level: ProblemLevel
    var message: String
    var code: String?
    var origin: DiagnosticOrigin = .check
}

struct DiagnosticStore {
    private var clang: [String: [StoredDiagnostic]] = [:]
    private var cargo: [StoredDiagnostic] = []
    private var build: [StoredDiagnostic] = []
    private var owner: [String: String] = [:]

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
        return clang.removeValue(forKey: path) != nil
    }

    mutating func replaceCargo(_ items: [StoredDiagnostic]) {
        cargo = items
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
        (clang.values.flatMap { $0 } + cargo + build).sorted {
            ($0.path, $0.byteStart) < ($1.path, $1.byteStart)
        }
    }

    var clangPaths: [String] {
        Array(clang.keys)
    }

    var buildDiagnostics: [StoredDiagnostic] {
        build
    }
}
