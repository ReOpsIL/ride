import Foundation

enum TargetRowKind: String, CaseIterable {
    case bin
    case lib
    case test
    case bench
    case example
    case custom
}

struct TargetRow: Identifiable, Equatable {
    let name: String
    let kind: TargetRowKind
    let detail: String

    var id: String { "\(kind.rawValue):\(name)" }
}

struct TargetGroup: Identifiable, Equatable {
    let kind: TargetRowKind
    let rows: [TargetRow]

    var id: String { kind.rawValue }
    var title: String { TargetRows.title(kind) }
}

enum TargetRows {
    static func grouped(_ rows: [TargetRow]) -> [TargetGroup] {
        TargetRowKind.allCases.compactMap { kind in
            let matching = rows.filter { $0.kind == kind }.sorted { less($0, $1) }
            return matching.isEmpty ? nil : TargetGroup(kind: kind, rows: matching)
        }
    }

    static func title(_ kind: TargetRowKind) -> String {
        switch kind {
        case .bin: "Binaries"
        case .lib: "Libraries"
        case .test: "Tests"
        case .bench: "Benchmarks"
        case .example: "Examples"
        case .custom: "Other"
        }
    }

    static func symbol(_ kind: TargetRowKind) -> String {
        switch kind {
        case .bin: "play.rectangle"
        case .lib: "shippingbox"
        case .test: "checkmark.diamond"
        case .bench: "speedometer"
        case .example: "lightbulb"
        case .custom: "hammer"
        }
    }

    static func displayName(_ row: TargetRow) -> String {
        let last = row.name.split(separator: "/").last.map(String.init) ?? row.name
        return last.isEmpty ? row.name : last
    }

    private static func less(_ a: TargetRow, _ b: TargetRow) -> Bool {
        let left = displayName(a)
        let right = displayName(b)
        if left == right {
            return a.name < b.name
        }
        return left.localizedStandardCompare(right) == .orderedAscending
    }
}
