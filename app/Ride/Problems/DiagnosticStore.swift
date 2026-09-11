import Foundation

enum ProblemLevel: Equatable, Hashable {
    case error
    case warning
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
}

struct DiagnosticStore {
    private var clang: [String: [StoredDiagnostic]] = [:]
    private var cargo: [StoredDiagnostic] = []

    mutating func insert(_ item: StoredDiagnostic) {
        clang[item.path, default: []].append(item)
    }

    mutating func replace(path: String, with items: [StoredDiagnostic]) {
        let mine = items.filter { $0.path == path }
        if mine.isEmpty {
            clang.removeValue(forKey: path)
        } else {
            clang[path] = mine
        }
    }

    @discardableResult
    mutating func remove(path: String) -> Bool {
        clang.removeValue(forKey: path) != nil
    }

    mutating func replaceCargo(_ items: [StoredDiagnostic]) {
        cargo = items
    }

    var snapshot: [StoredDiagnostic] {
        (clang.values.flatMap { $0 } + cargo).sorted {
            ($0.path, $0.byteStart) < ($1.path, $1.byteStart)
        }
    }

    var clangPaths: [String] {
        Array(clang.keys)
    }
}
